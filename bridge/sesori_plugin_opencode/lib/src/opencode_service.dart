import "dart:async";
import "dart:io" as io;
import "dart:math";

import "package:json_annotation/json_annotation.dart" show CheckedFromJsonException;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginAgent,
        PluginApiException,
        PluginCommand,
        PluginCommandInvocationContext,
        PluginCommandSource,
        PluginMessageWithParts,
        PluginPermissionReply,
        PluginProject,
        PluginPromptPart,
        PluginProvidersResult,
        PluginSession,
        PluginSessionVariant;
import "package:sesori_shared/sesori_shared.dart" show ProjectActivitySummary, StringExtensions;

import "../opencode_plugin.dart";

class OpenCodeService {
  /// Name of the artificial slash command injected into [getCommands] so the
  /// mobile app can trigger OpenCode's manual compaction.
  ///
  /// OpenCode does not list `/compact` in `GET /command` — it is a client-side
  /// built-in in OpenCode's own TUI/web — so the plugin synthesizes it here and
  /// routes its invocation to the summarize endpoint in [sendCommand].
  static const String compactionCommandName = "compact";

  static const PluginCommand _compactionCommand = PluginCommand(
    name: compactionCommandName,
    description: "Summarize the conversation so far to free up the context window",
    provider: null,
    source: PluginCommandSource.command,
    subtask: null,
  );

  final OpenCodeRepository repository;
  final ActiveSessionTracker tracker;
  final OpenCodeCommandTracker commandTracker;
  final Duration _commandDispatchFastFailWindow;
  static final Random _secureRandom = Random.secure();

  /// Signals that service-owned tracker bookkeeping changed the activity
  /// summary and the consumer (the plugin) should re-emit it. Broadcast so the
  /// single plugin subscriber can attach in its constructor; the service never
  /// emits SSE events itself (the plugin owns that decision).
  final StreamController<void> _summaryInvalidations = StreamController<void>.broadcast();

  /// Session IDs with an in-flight one-shot parent-ID lookup, used to dedupe
  /// concurrent resolutions. This is event-driven, not polling: a lookup fires
  /// only when a busy/retry status arrives for a session whose parent is still
  /// unknown, and the entry is cleared once the lookup settles.
  final Set<String> _parentIdLookupsInFlight = {};

  /// [commandDispatchFastFailWindow] bounds how long [sendCommand] waits on
  /// OpenCode's synchronous command/summarize endpoints before treating the run
  /// as accepted and detaching (see [sendCommand]). Genuine dispatch rejections
  /// (unknown command/session, missing model, server down) surface from
  /// localhost within milliseconds, so 1s is enough to catch them while keeping
  /// the phone's "accepted" feedback snappy.
  OpenCodeService(
    this.repository,
    this.tracker,
    this.commandTracker, {
    Duration commandDispatchFastFailWindow = const Duration(seconds: 1),
  }) : _commandDispatchFastFailWindow = commandDispatchFastFailWindow;

  Future<List<PluginProject>> getProjects() async {
    final projects = await repository.getProjects();
    var summaryChanged = tracker.updateProjectWorktrees(
      worktrees: projects.map((project) => project.project.id).toSet(),
    );
    for (final project in projects) {
      for (final sandbox in project.sandboxes) {
        summaryChanged =
            tracker.registerWorktreeAlias(
              directory: sandbox,
              worktree: project.project.id,
            ) ||
            summaryChanged;
      }
    }
    if (summaryChanged && !_summaryInvalidations.isClosed) {
      _summaryInvalidations.add(null);
    }
    return projects.map((project) => project.project).toList();
  }

  Future<PluginProvidersResult> getProviders({required String projectId}) {
    return repository.getProviders(
      directory: projectId,
    );
  }

  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    final commands = await repository.getCommands(projectId: projectId);
    // `compact` is reserved because its dispatch path is /summarize, not the
    // ordinary /command endpoint. Never expose an upstream collision with
    // semantics that differ from the synthetic catalog entry.
    return [
      ...commands.where((command) => !_isCompactionCommand(command.name)),
      _compactionCommand,
    ];
  }

  /// Returns the agents available for [projectId] (a worktree directory).
  ///
  /// OpenCode resolves agents per project, so a directory is always sent.
  /// When [projectId] is `null` or blank we fall back to the bridge's own
  /// CWD, which yields the global agent set.
  Future<List<PluginAgent>> getAgents({required String? projectId}) {
    final String directory;
    final normalized = projectId?.normalize();
    if (normalized == null) {
      directory = io.Directory.current.path;
      Log.d("getAgents: no projectId given, falling back to bridge CWD: $directory");
    } else {
      directory = normalized;
    }
    return repository.getAgents(directory: directory);
  }

  Future<List<Session>> getSessions({
    required String worktree,
    int? start,
    int? limit,
  }) async {
    final sessions = await repository.getSessions(worktree: worktree);

    final afterStart = _applyStart(sessions, start);
    return _applyLimit(afterStart, limit);
  }

  /// Returns the pending questions to surface on [sessionId]'s screen — its own
  /// plus any descendant (sub-agent) session whose top-most root resolves to
  /// [sessionId] — each paired with its resolved display (root) session.
  Future<List<({QuestionRequest request, String displaySessionId})>> getPendingQuestionsForSession({
    required String sessionId,
  }) async {
    final directory = await _resolveSessionDirectory(sessionId: sessionId);
    if (directory == null) {
      // `getPendingQuestions` is directory-scoped: OpenCode defaults an omitted
      // directory header to its own cwd. An unscoped query would therefore only
      // ever return the cwd instance's questions, so a session whose worktree
      // differs would be reported as having no pending questions — silently
      // dropping a prompt that may still exist upstream. Fail loudly instead,
      // consistent with `rejectQuestion`.
      throw PluginApiException(
        "GET /session/$sessionId/question",
        502,
        message: "could not resolve session directory",
      );
    }

    // `getPendingQuestions` is directory-scoped and may return questions for
    // sibling/child sessions in the same worktree. Keep the ones that belong on
    // this session's screen: its own, plus any descendant whose top-most root is
    // this session (so a sub-agent's prompt surfaces on the root).
    final all = await repository.getPendingQuestions(directory: directory);
    return all
        .map((q) => (request: q, displaySessionId: tracker.resolveDisplaySessionId(q.sessionID)))
        .where((e) => e.request.sessionID == sessionId || e.displaySessionId == sessionId)
        .toList();
  }

  /// Returns the pending permissions to surface on [sessionId]'s screen — its
  /// own plus any descendant (sub-agent) session whose top-most root resolves to
  /// [sessionId] — each paired with its resolved display (root) session.
  Future<List<({PermissionRequest request, String displaySessionId})>> getPendingPermissionsForSession({
    required String sessionId,
  }) async {
    final directory = await _resolveSessionDirectory(sessionId: sessionId);
    if (directory == null) {
      throw PluginApiException(
        "GET /session/$sessionId/permission",
        502,
        message: "could not resolve session directory",
      );
    }

    // `getPendingPermissions` is directory-scoped (returns every pending
    // permission in the worktree). Keep the ones that belong on this session's
    // screen: its own, plus any descendant whose top-most root is this session
    // (so a sub-agent's permission surfaces on the root).
    final all = await repository.getPendingPermissions(directory: directory);
    return all
        .map((p) => (request: p, displaySessionId: tracker.resolveDisplaySessionId(p.sessionID)))
        .where((e) => e.request.sessionID == sessionId || e.displaySessionId == sessionId)
        .toList();
  }

  /// Resolves the top-most root "display" session for [sessionId] (see
  /// [ActiveSessionTracker.resolveDisplaySessionId]). Used by the plugin to
  /// stamp `displaySessionId` on outbound permission/question events.
  String resolveDisplaySessionId(String sessionId) => tracker.resolveDisplaySessionId(sessionId);

  /// Resolves the directory for [sessionId], fetching and registering it from
  /// the repository if the tracker has not learned it yet.
  Future<String?> _resolveSessionDirectory({required String sessionId}) async {
    final knownDirectory = tracker.getSessionDirectory(sessionId: sessionId);
    if (knownDirectory != null) return knownDirectory;

    try {
      final session = await repository.getSession(
        sessionId: sessionId,
        directory: null,
      );
      tracker.registerSession(
        sessionId: sessionId,
        directory: session.directory,
        parentId: session.parentID,
      );
      Log.d(
        "_resolveSessionDirectory: resolved missing directory "
        "for session $sessionId via getSession: ${session.directory}",
      );
      return session.directory;
    } catch (e) {
      Log.w("_resolveSessionDirectory: failed to resolve directory for session $sessionId: $e");
      return null;
    }
  }

  Future<List<PluginMessageWithParts>> getMessages({
    required String sessionId,
    required String? directory,
    required List<PluginCommandInvocationContext> acceptedCommands,
  }) async {
    try {
      return await repository.getMessages(
        sessionId: sessionId,
        directory: directory,
        acceptedCommands: acceptedCommands,
      );
    } on OpenCodeApiException {
      rethrow;
    } on PluginApiException {
      rethrow;
    } catch (error, stackTrace) {
      if (!_isLikelyDecodeOrSchemaDriftError(error)) {
        rethrow;
      }
      Log.w("Failed to decode messages for session $sessionId: $error\n$stackTrace");
      throw PluginApiException("GET /session/$sessionId/message", 502);
    }
  }

  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) async {
    final session = await repository.createSession(
      directory: directory,
      parentSessionId: parentSessionId,
    );

    if (parts.isNotEmpty) {
      try {
        await repository.sendPrompt(
          sessionId: session.id,
          directory: session.directory,
          parts: parts,
          agent: agent,
          variant: variant,
          model: model,
        );
      } catch (e, st) {
        await _deleteFailedCreatedSession(session: session, error: e, stackTrace: st);
        rethrow;
      }
    }

    tracker.registerSession(
      sessionId: session.id,
      directory: session.directory,
      parentId: session.parentID,
    );
    return session;
  }

  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    final directory = _getTrackedDirectory(sessionId: sessionId);
    return repository.sendPrompt(
      sessionId: sessionId,
      directory: directory,
      parts: parts,
      agent: agent,
      variant: variant,
      model: model,
    );
  }

  Future<String?> sendCommand({
    required String sessionId,
    required String invocationId,
    required String command,
    required String arguments,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) async {
    final directory = _getTrackedDirectory(sessionId: sessionId);
    // The artificial "compact" command (see [compactionCommandName]) has no
    // OpenCode command counterpart — route it to the summarize endpoint, which
    // performs manual compaction. Everything else is a real slash command.
    final String? backendMessageId;
    final Future<void> sendFuture;
    if (_isCompactionCommand(command)) {
      final compactionModel = _requireCompactionModel(model: model, sessionId: sessionId);
      backendMessageId = null;
      commandTracker.registerDispatch(
        sessionId: sessionId,
        invocationId: invocationId,
        name: command,
        arguments: arguments,
        backendMessageId: null,
      );
      sendFuture = _compact(
        sessionId: sessionId,
        directory: directory,
        arguments: arguments,
        agent: agent,
        variant: variant,
        model: compactionModel,
      );
    } else {
      backendMessageId = _newCommandMessageId();
      commandTracker.registerDispatch(
        sessionId: sessionId,
        invocationId: invocationId,
        name: command,
        arguments: arguments,
        backendMessageId: backendMessageId,
      );
      sendFuture = repository.sendCommand(
        sessionId: sessionId,
        directory: directory,
        messageId: backendMessageId,
        command: command,
        arguments: arguments,
        agent: agent,
        variant: variant,
        model: model,
      );
    }
    // OpenCode's POST /session/:id/command and /summarize endpoints are both
    // synchronous — they respond only after the agent run completes, and no
    // async variant exists upstream (see OpenCodeApi.sendCommand/summarize).
    // The BridgePluginApi contract requires sendCommand to complete once the
    // command is accepted, so dispatch with a fast-fail window: failures
    // raised within the window (unknown command/agent, missing session,
    // server down) propagate to the caller, while a run that outlives the
    // window is treated as accepted and detached — its progress and errors
    // stream over SSE.
    //
    // `onTimeout` (rather than catching [TimeoutException]) fires only when
    // the window itself elapses, so a genuine TimeoutException raised by the
    // send chain within the window still propagates as a dispatch failure.
    try {
      await sendFuture.timeout(
        _commandDispatchFastFailWindow,
        onTimeout: () {
          unawaited(
            sendFuture.catchError((Object error, StackTrace stackTrace) {
              Log.w(
                "command '$command' for session $sessionId failed after dispatch",
                error,
                stackTrace,
              );
            }),
          );
        },
      );
      return backendMessageId;
    } catch (_) {
      commandTracker.cancelDispatch(
        sessionId: sessionId,
        invocationId: invocationId,
      );
      rethrow;
    }
  }

  static String _newCommandMessageId() {
    final hex = List.generate(
      16,
      (_) => _secureRandom.nextInt(256).toRadixString(16).padLeft(2, "0"),
    ).join();
    return "msg_sesori_$hex";
  }

  static bool _isCompactionCommand(String command) {
    return command == compactionCommandName || command == "/$compactionCommandName";
  }

  Future<void> _compact({
    required String sessionId,
    required String? directory,
    required String arguments,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID}) model,
  }) async {
    final instructions = arguments.normalize();
    if (instructions != null) {
      // OpenCode's summarize payload has no instructions field. A no-reply
      // prompt persists the guidance as context without running the agent.
      await repository.addCompactionInstructions(
        sessionId: sessionId,
        directory: directory,
        instructions: instructions,
        agent: agent,
        variant: variant,
        model: model,
      );
    }
    await repository.summarize(
      sessionId: sessionId,
      directory: directory,
      model: model,
    );
  }

  /// Compaction needs an explicit provider/model (OpenCode's summarize payload
  /// has no server-side default). The session model is normally threaded in
  /// from the mobile prompt request; if it is absent we fail loudly rather than
  /// silently dropping the compaction.
  ({String providerID, String modelID}) _requireCompactionModel({
    required ({String providerID, String modelID})? model,
    required String sessionId,
  }) {
    if (model == null) {
      throw PluginApiException(
        "POST /session/$sessionId/summarize",
        400,
        message: "compaction requires a model selection",
      );
    }
    return model;
  }

  Future<({bool found, String? resolvedSessionId, bool summaryChanged})> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    final directory = await _resolveSessionDirectory(sessionId: sessionId);
    if (directory == null) {
      throw PluginApiException(
        "POST /question/$questionId/reply",
        502,
        message: "could not resolve session directory",
      );
    }
    try {
      await repository.replyToQuestion(
        questionId: questionId,
        directory: directory,
        body: QuestionReplyBody(answers: answers),
      );
    } on OpenCodeApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      Log.w("question already resolved upstream (404), reconciling tracker: ${e.endpoint}", e);
    }
    return tracker.clearPendingQuestion(questionId: questionId, sessionId: sessionId);
  }

  Future<({bool found, String? resolvedSessionId, bool summaryChanged})> rejectQuestion({
    required String questionId,
    required String? sessionId,
  }) async {
    final resolvedSessionId = sessionId ?? tracker.getSessionIdForQuestion(questionId: questionId);

    // Older mobile clients may omit sessionId. We accept that in those cases
    // we can only clear local pending state; the upstream question may remain.
    if (resolvedSessionId == null) {
      return tracker.clearPendingQuestion(questionId: questionId, sessionId: null);
    }

    final directory = await _resolveSessionDirectory(sessionId: resolvedSessionId);
    if (directory == null) {
      throw PluginApiException(
        "POST /question/$questionId/reject",
        502,
        message: "could not resolve session directory",
      );
    }

    try {
      await repository.rejectQuestion(
        questionId: questionId,
        directory: directory,
      );
    } on OpenCodeApiException catch (e) {
      // A 404 after a scoped request means the question is already gone
      // upstream; reconcile local state so the UI does not stay stuck.
      if (e.statusCode != 404) rethrow;
      Log.w("question already resolved upstream (404), reconciling tracker: ${e.endpoint}", e);
    }
    return tracker.clearPendingQuestion(questionId: questionId, sessionId: resolvedSessionId);
  }

  Future<({bool found, String? resolvedSessionId, bool summaryChanged})> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    final directory = await _resolveSessionDirectory(sessionId: sessionId);
    if (directory == null) {
      throw PluginApiException(
        "POST /permission/$requestId/reply",
        502,
        message: "could not resolve session directory",
      );
    }
    try {
      await repository.replyToPermission(
        requestId: requestId,
        directory: directory,
        reply: reply,
      );
    } on OpenCodeApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      Log.w("permission already resolved upstream (404), reconciling tracker: ${e.endpoint}", e);
    }
    return tracker.clearPendingPermission(sessionId: sessionId, requestId: requestId);
  }

  /// Fires when service-owned tracker updates change activity-summary grouping.
  /// The plugin subscribes and re-emits the summary.
  Stream<void> get summaryInvalidations => _summaryInvalidations.stream;

  bool handleSseEvent(SseEventData event, String? directory) {
    final changed = tracker.handleEvent(event, directory);
    _maybeResolveParentId(event, directory);
    return changed;
  }

  /// When a busy/retry status arrives for a session whose parent attribution is
  /// still unknown, kick off a one-shot lookup so the session is grouped under
  /// its real root instead of becoming a phantom root.
  ///
  /// OpenCode emits `session.created` (which carries `parentID`) before
  /// `session.status:busy`, but a dropped/late `session.created` frame leaves
  /// the tracker without the parent ID — and `session.status` has no `parentID`
  /// field to recover it. This resolves the gap on demand.
  void _maybeResolveParentId(SseEventData event, String? directory) {
    if (event is! SseSessionStatus) return;
    final status = event.status;
    if (status is! SessionStatusBusy && status is! SessionStatusRetry) return;

    final sessionId = event.sessionID;
    if (tracker.knowsParent(sessionId: sessionId)) return;
    if (_parentIdLookupsInFlight.contains(sessionId)) return;

    _parentIdLookupsInFlight.add(sessionId);
    unawaited(_resolveParentId(sessionId: sessionId, directory: directory));
  }

  Future<void> _resolveParentId({
    required String sessionId,
    required String? directory,
  }) async {
    try {
      final lookupDirectory = directory ?? tracker.getSessionDirectory(sessionId: sessionId);
      final session = await repository.getSession(
        sessionId: sessionId,
        directory: lookupDirectory,
      );
      final changed = tracker.registerSession(
        sessionId: sessionId,
        directory: session.directory,
        parentId: session.parentID,
      );
      if (changed && !_summaryInvalidations.isClosed) {
        _summaryInvalidations.add(null);
      }
    } catch (e, st) {
      // Best-effort: leave the parent unknown so a later status event can retry.
      Log.w("failed to resolve parentID for session $sessionId", e, st);
    } finally {
      _parentIdLookupsInFlight.remove(sessionId);
    }
  }

  Future<void> coldStart() async {
    final trackerSw = Stopwatch()..start();
    await tracker.coldStart();
    Log.v("[coldStart] tracker.coldStart finished in ${trackerSw.elapsedMilliseconds}ms");
    try {
      final hydrateSw = Stopwatch()..start();
      await _hydratePendingInput();
      Log.v("[coldStart] hydratePendingInput finished in ${hydrateSw.elapsedMilliseconds}ms");
    } catch (e, st) {
      Log.w("coldStart: failed to hydrate pending input: $e\n$st");
    }
  }

  /// Best-effort hydration of pending questions and permissions after the
  /// core active-session baseline is ready. Failures are logged but do NOT
  /// abort cold start — [ActiveSessionTracker.coldStart] succeeds
  /// independently.
  Future<void> _hydratePendingInput() async {
    // Hydrate the OpenCode server's cwd instance AND every directory sessions
    // may run under (project worktrees plus moved-location aliases): an
    // unscoped query only covers the cwd, and the cwd may not itself be a
    // listed worktree. Overlapping results are de-duplicated by the tracker
    // when grouping by session.
    final directories = <String?>{null, ...tracker.sessionDiscoveryDirectories};
    await (
      _hydratePendingQuestions(directories),
      _hydratePendingPermissions(directories),
    ).wait;
  }

  Future<void> _hydratePendingQuestions(Iterable<String?> directories) async {
    final all = <QuestionRequest>[];
    await Future.wait(
      directories.map((directory) async {
        try {
          all.addAll(await repository.getPendingQuestions(directory: directory));
        } catch (e, st) {
          Log.w("coldStart: failed to hydrate pending questions for ${directory ?? "<cwd>"}", e, st);
        }
      }),
    );
    tracker.populatePendingQuestions(questions: all);
  }

  Future<void> _hydratePendingPermissions(Iterable<String?> directories) async {
    final all = <PermissionRequest>[];
    await Future.wait(
      directories.map((directory) async {
        try {
          all.addAll(await repository.getPendingPermissions(directory: directory));
        } catch (e, st) {
          Log.w("coldStart: failed to hydrate pending permissions for ${directory ?? "<cwd>"}", e, st);
        }
      }),
    );
    tracker.populatePendingPermissions(permissions: all);
  }

  void reset() {
    tracker.reset();
    // Drop any in-flight parent lookups so a post-reconnect status event can
    // re-resolve immediately instead of being suppressed by a stale entry. The
    // orphaned lookups still settle harmlessly: their `finally` is a no-op on an
    // already-absent key and their tracker writes target the post-reset state.
    _parentIdLookupsInFlight.clear();
  }

  /// Releases the summary-invalidation stream. Called by the plugin on dispose.
  /// Distinct from [reset] (invoked on SSE reconnect), which must keep the
  /// stream alive so the plugin's subscription survives reconnects.
  Future<void> dispose() async {
    await _summaryInvalidations.close();
  }

  List<ProjectActivitySummary> buildSummary() {
    return tracker.buildSummary();
  }

  List<Session> _applyStart(List<Session> sessions, int? start) {
    if (start == null || start <= 0) return sessions;
    if (sessions.length > start) return sessions.sublist(start);
    return [];
  }

  List<Session> _applyLimit(List<Session> sessions, int? limit) {
    if (limit == null || limit <= 0) return sessions;
    if (sessions.length > limit) return sessions.sublist(0, limit);
    return sessions;
  }

  bool _isLikelyDecodeOrSchemaDriftError(Object error) {
    return error is FormatException || error is TypeError || error is CheckedFromJsonException;
  }

  String? _getTrackedDirectory({required String sessionId}) {
    final directory = tracker.getSessionDirectory(sessionId: sessionId);
    if (directory == null) {
      Log.w("directory missing for session $sessionId. Defaulting to bridge CWD as directory.");
    }
    return directory;
  }

  Future<void> _deleteFailedCreatedSession({
    required PluginSession session,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    Log.w("createSession: prompt send failed for session ${session.id}: $error\n$stackTrace");
    try {
      await repository.deleteSession(
        sessionId: session.id,
        directory: session.directory,
      );
    } catch (cleanupError, cleanupStackTrace) {
      Log.w(
        "createSession: failed to clean up session ${session.id} after prompt failure: $cleanupError\n$cleanupStackTrace",
      );
    }
  }
}

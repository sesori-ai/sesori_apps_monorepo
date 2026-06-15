import "dart:async";
import "dart:io" as io;

import "package:json_annotation/json_annotation.dart" show CheckedFromJsonException;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginAgent,
        PluginApiException,
        PluginCommand,
        PluginCommandSource,
        PluginPermissionReply,
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
  final Duration _commandDispatchFastFailWindow;

  /// [commandDispatchFastFailWindow] bounds how long [sendCommand] waits on
  /// OpenCode's synchronous command/summarize endpoints before treating the run
  /// as accepted and detaching (see [sendCommand]). Genuine dispatch rejections
  /// (unknown command/session, missing model, server down) surface from
  /// localhost within milliseconds, so 1s is enough to catch them while keeping
  /// the phone's "accepted" feedback snappy.
  OpenCodeService(
    this.repository,
    this.tracker, {
    Duration commandDispatchFastFailWindow = const Duration(seconds: 1),
  }) : _commandDispatchFastFailWindow = commandDispatchFastFailWindow;

  Future<List<Project>> getProjects() {
    return repository.getProjects();
  }

  Future<PluginProvidersResult> getProviders({required String projectId}) {
    return repository.getProviders(
      directory: projectId,
    );
  }

  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    final commands = await repository.getCommands(projectId: projectId);
    // Synthesize the compaction command unless the project already defines one
    // with the same name (e.g. a user-authored `compact` config command).
    if (commands.any((command) => command.name == compactionCommandName)) {
      return commands;
    }
    return [...commands, _compactionCommand];
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

  Future<List<PendingQuestion>> getPendingQuestionsForSession({
    required String sessionId,
  }) async {
    final directory = await _resolveSessionDirectory(sessionId: sessionId);

    // Subagent (child) sessions are non-interactive and never ask questions, so
    // only the session's own pending questions are relevant. `getPendingQuestions`
    // is directory-scoped and may return questions for sibling sessions in the
    // same worktree, so filter to this session. If the directory cannot be
    // resolved, fall back to an unscoped query and filter by sessionID.
    final all = await repository.getPendingQuestions(directory: directory);
    return all.where((question) => question.sessionID == sessionId).toList();
  }

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
      tracker.registerSession(sessionId: sessionId, directory: session.directory);
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

  Future<List<MessageWithParts>> getMessages({
    required String sessionId,
    required String? directory,
  }) async {
    try {
      return await repository.api.getMessages(sessionId: sessionId, directory: directory);
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

    tracker.registerSession(sessionId: session.id, directory: session.directory);
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

  Future<void> sendCommand({
    required String sessionId,
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
    final sendFuture = command == compactionCommandName
        ? repository.summarize(
            sessionId: sessionId,
            directory: directory,
            model: _requireCompactionModel(model: model, sessionId: sessionId),
          )
        : repository.sendCommand(
            sessionId: sessionId,
            directory: directory,
            command: command,
            arguments: arguments,
            agent: agent,
            variant: variant,
            model: model,
          );
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
    await sendFuture.timeout(
      _commandDispatchFastFailWindow,
      onTimeout: () {
        unawaited(
          sendFuture.catchError((Object e, StackTrace s) {
            Log.w(
              "command '$command' for session $sessionId "
              "failed after dispatch: $e",
              e,
              s,
            );
          }),
        );
      },
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
    try {
      await repository.replyToQuestion(
        questionId: questionId,
        directory: directory,
        body: QuestionReplyBody(answers: answers),
      );
    } on OpenCodeApiException catch (e) {
      if (e.statusCode != 404 || directory == null) rethrow;
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
    try {
      await repository.replyToPermission(
        requestId: requestId,
        directory: directory,
        reply: reply,
      );
    } on OpenCodeApiException catch (e) {
      if (e.statusCode != 404 || directory == null) rethrow;
      Log.w("permission already resolved upstream (404), reconciling tracker: ${e.endpoint}", e);
    }
    return tracker.clearPendingPermission(sessionId: sessionId, requestId: requestId);
  }

  bool handleSseEvent(SseEventData event, String? directory) {
    return tracker.handleEvent(event, directory);
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
    await (
      repository
          .getPendingQuestions(directory: null)
          .then((questions) => tracker.populatePendingQuestions(questions: questions))
          .catchError((Object e, StackTrace st) {
            Log.w("coldStart: failed to hydrate pending questions", e, st);
          }),
      repository
          .getPendingPermissions(directory: null)
          .then((permissions) => tracker.populatePendingPermissions(permissions: permissions))
          .catchError((Object e, StackTrace st) {
            Log.w("coldStart: failed to hydrate pending permissions", e, st);
          }),
    ).wait;
  }

  void reset() {
    tracker.reset();
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

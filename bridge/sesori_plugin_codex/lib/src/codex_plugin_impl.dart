import "dart:async";
import "dart:io" show Directory;

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "approval_registry.dart";
import "codex_app_server_client.dart";
import "codex_event_mapper.dart";
import "codex_skill_reader.dart";
import "session_rollout_reader.dart";

/// Phase 4 of the Codex backend plugin.
///
/// Phases 2/3 brought up the WebSocket client, the `initialize` handshake,
/// and the read path via `~/.codex/session_index.jsonl` and rollout files.
/// Phase 4 adds the live write path:
///
///   - [createSession] → `thread/start` (+ first `turn/start` if parts are
///     supplied) so users can start a new codex conversation from mobile.
///   - [sendPrompt]    → `turn/start` on an existing thread.
///   - [abortSession]  → `turn/interrupt` against the active turn.
///   - The server notification stream is pumped through [CodexEventMapper]
///     into [events] so mobile UI gets live streaming output.
///   - Live session status (running/idle) is tracked from `turn/started`
///     and `turn/completed` notifications so [getSessionStatuses] returns
///     non-empty data while sessions are alive.
///
/// Approval/permission flows still throw — those land in Phase 5.
class CodexPlugin implements BridgePluginApi {
  final String _serverUrl;
  // ignore: unused_field
  final String? _capabilityToken;
  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;
  final CodexAppServerClient Function() _clientFactory;
  final SessionRolloutReader _rolloutReader;
  final CodexSkillReader _skillReader;
  final CodexEventMapper _eventMapper;
  final String _projectCwd;

  CodexAppServerClient? _client;
  Future<bool>? _connectFuture;
  StreamSubscription<CodexServerNotification>? _notificationSubscription;
  ApprovalRegistry? _approvalRegistry;

  /// Most recent turn id observed per thread, used to target
  /// `turn/interrupt`. Cleared on `turn/completed` / `error`.
  final Map<String, String> _activeTurnByThread = {};

  /// Running session status keyed by thread id — fed by `turn/started`,
  /// `turn/completed`, `error` notifications.
  final Map<String, PluginSessionStatus> _sessionStatuses = {};

  factory CodexPlugin({
    required String serverUrl,
    String? capabilityToken,
    CodexAppServerClient Function()? clientFactory,
    SessionRolloutReader? rolloutReader,
    CodexSkillReader? skillReader,
    CodexEventMapper? eventMapper,
    String? projectCwd,
  }) {
    final resolvedProjectCwd = projectCwd ?? Directory.current.path;
    return CodexPlugin._(
      serverUrl: serverUrl,
      capabilityToken: capabilityToken,
      clientFactory:
          clientFactory ??
          () => CodexAppServerClient(
            serverUrl: serverUrl,
            capabilityToken: capabilityToken,
          ),
      rolloutReader: rolloutReader ?? SessionRolloutReader(),
      skillReader:
          skillReader ?? CodexSkillReader(projectCwd: resolvedProjectCwd),
      eventMapper: eventMapper ?? const CodexEventMapper(),
      projectCwd: resolvedProjectCwd,
    );
  }

  CodexPlugin._({
    required String serverUrl,
    required String? capabilityToken,
    required CodexAppServerClient Function() clientFactory,
    required SessionRolloutReader rolloutReader,
    required CodexSkillReader skillReader,
    required CodexEventMapper eventMapper,
    required String projectCwd,
  }) : _serverUrl = serverUrl,
       _capabilityToken = capabilityToken,
       _clientFactory = clientFactory,
       _rolloutReader = rolloutReader,
       _skillReader = skillReader,
       _eventMapper = eventMapper,
       _projectCwd = projectCwd,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();

  String get serverUrl => _serverUrl;

  @override
  String get id => "codex";

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  /// Lazily opens the WS connection, performs `initialize`, and starts
  /// piping server notifications into the bridge event buffer.
  ///
  /// Memoises the in-flight future so concurrent callers share one
  /// connection attempt; subsequent calls return the cached result.
  Future<bool> _ensureConnected() {
    final existing = _connectFuture;
    if (existing != null) return existing;
    final future = () async {
      final client = _clientFactory();
      _client = client;
      try {
        await client.connect();
        _subscribeToNotifications(client);
        _attachApprovalRegistry(client);
        return true;
      } catch (error) {
        await client.dispose();
        _client = null;
        _connectFuture = null;
        return Future<bool>.error(error);
      }
    }();
    _connectFuture = future.catchError((Object _) => false);
    return _connectFuture!;
  }

  /// Wires the codex notification stream into the bridge event buffer,
  /// while side-effecting on a few notifications to keep session-status
  /// and turn-id bookkeeping current.
  void _subscribeToNotifications(CodexAppServerClient client) {
    _notificationSubscription = client.notifications.listen((notification) {
      _maintainBookkeeping(notification);
      final mapped = _eventMapper.map(notification);
      if (mapped != null) _eventBuffer.add(mapped);
    });
  }

  /// Wires codex server-originated requests (approval prompts and
  /// elicitations) through the [ApprovalRegistry] so they surface as
  /// bridge permission/question events.
  void _attachApprovalRegistry(CodexAppServerClient client) {
    final registry = ApprovalRegistry(
      emit: _eventBuffer.add,
      respond: (id, result) =>
          client.respondToServerRequest(id: id, result: result),
      respondError: (id, code, message) =>
          client.respondToServerRequestWithError(
            id: id,
            code: code,
            message: message,
          ),
    );
    _approvalRegistry = registry;
    registry.attach(client.serverRequests);
  }

  void _maintainBookkeeping(CodexServerNotification notification) {
    final params = notification.params;
    final threadId = params["threadId"] as String?;
    switch (notification.method) {
      case "turn/started":
        if (threadId == null) return;
        final turn = (params["turn"] as Map?)?.cast<String, dynamic>();
        final turnId = turn?["id"] as String?;
        if (turnId != null) _activeTurnByThread[threadId] = turnId;
        _sessionStatuses[threadId] = const PluginSessionStatus.busy();
      case "turn/completed":
        if (threadId == null) return;
        _activeTurnByThread.remove(threadId);
        _sessionStatuses[threadId] = const PluginSessionStatus.idle();
      case "error":
        if (threadId == null) return;
        _activeTurnByThread.remove(threadId);
        // PluginSessionStatus has no explicit "error" — surfacing as idle
        // and letting the mapped BridgeSseSessionError carry the signal.
        _sessionStatuses[threadId] = const PluginSessionStatus.idle();
      case "thread/closed":
        if (threadId == null) return;
        _activeTurnByThread.remove(threadId);
        _sessionStatuses.remove(threadId);
      case "thread/started":
        final thread = (params["thread"] as Map?)?.cast<String, dynamic>();
        final id = thread?["id"] as String?;
        if (id == null) return;
        _sessionStatuses[id] = const PluginSessionStatus.idle();
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      return await _ensureConnected();
    } catch (_) {
      return false;
    }
  }

  PluginProject _synthesizedProject() {
    final updated = DateTime.now().millisecondsSinceEpoch;
    return PluginProject(
      id: _projectCwd,
      name: p.basename(_projectCwd).isEmpty
          ? _projectCwd
          : p.basename(_projectCwd),
      time: PluginProjectTime(created: updated, updated: updated),
    );
  }

  @override
  Future<List<PluginProject>> getProjects() async => [_synthesizedProject()];

  @override
  Future<PluginProject> getProject(String projectId) async =>
      _synthesizedProject();

  @override
  Future<List<PluginSession>> getSessions(
    String projectId, {
    int? start,
    int? limit,
  }) async {
    final records = _rolloutReader.listSessions();
    final filtered = records.where((r) => r.cwd == projectId);
    final mapped = filtered.map(_toPluginSession).toList(growable: false);
    final from = start ?? 0;
    final until = limit == null
        ? mapped.length
        : (from + limit).clamp(0, mapped.length);
    if (from >= mapped.length) return const [];
    return mapped.sublist(from, until);
  }

  PluginSession _toPluginSession(CodexSessionRecord record) {
    final created = record.createdAt?.millisecondsSinceEpoch;
    final updated = record.updatedAt?.millisecondsSinceEpoch ?? created;
    return PluginSession(
      id: record.id,
      projectID: _projectCwd,
      directory: record.cwd ?? _projectCwd,
      parentID: null,
      title: record.threadName,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
      summary: null,
    );
  }

  @override
  Future<List<PluginCommand>> getCommands({
    required String? projectId,
  }) async {
    final skills = _skillReader.list();
    return [
      for (final skill in skills)
        PluginCommand(
          name: skill.name,
          description: skill.description.isEmpty ? null : skill.description,
          source: PluginCommandSource.skill,
          provider: null,
        ),
    ];
  }

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final client = await _connectedClient();
    final params = <String, dynamic>{
      "cwd": directory,
      "experimentalRawEvents": false,
      "persistExtendedHistory": false,
    };
    if (model != null) {
      params["model"] = model.modelID;
      params["modelProvider"] = model.providerID;
    }
    final result = await client.request(method: "thread/start", params: params);
    final thread = _extractThread(result);
    final threadId = thread?["id"] as String?;
    if (threadId == null) {
      throw StateError("thread/start response missing thread.id");
    }
    if (parts.isNotEmpty) {
      await _startTurn(client: client, threadId: threadId, parts: parts);
    }
    return PluginSession(
      id: threadId,
      projectID: _projectCwd,
      directory: (thread?["cwd"] as String?) ?? directory,
      parentID: parentSessionId,
      title: thread?["name"] as String?,
      time: _timeFromThread(thread),
      summary: null,
    );
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final client = await _connectedClient();
    await _startTurn(
      client: client,
      threadId: sessionId,
      parts: parts,
      model: model,
    );
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    // Codex doesn't have a generic third-party-extensible slash-command
    // API; we encode the invocation as plain user text so codex's TUI-style
    // slash handlers (e.g. `/plan`) can pick it up if they're registered.
    final body = arguments.isEmpty ? "/$command" : "/$command $arguments";
    await _startTurn(
      client: await _connectedClient(),
      threadId: sessionId,
      parts: [PluginPromptPart.text(text: body)],
      model: model,
    );
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    final turnId = _activeTurnByThread[sessionId];
    if (turnId == null) return;
    final client = _client;
    if (client == null) return;
    try {
      await client.request(
        method: "turn/interrupt",
        params: {"threadId": sessionId, "turnId": turnId},
      );
    } on CodexRpcException catch (error) {
      // If the turn already completed before our interrupt arrived,
      // codex returns a "not found" — treat as already-aborted.
      if (error.code != -32602) rethrow;
    } finally {
      _activeTurnByThread.remove(sessionId);
    }
  }

  Future<void> _startTurn({
    required CodexAppServerClient client,
    required String threadId,
    required List<PluginPromptPart> parts,
    ({String providerID, String modelID})? model,
  }) async {
    final input = parts.map(_promptPartToUserInput).whereType<Map<String, dynamic>>().toList();
    if (input.isEmpty) return;
    final params = <String, dynamic>{"threadId": threadId, "input": input};
    if (model != null) {
      params["model"] = model.modelID;
    }
    await client.request(method: "turn/start", params: params);
  }

  Map<String, dynamic>? _promptPartToUserInput(PluginPromptPart part) {
    return switch (part) {
      PluginPromptPartText(:final text) => {
        "type": "text",
        "text": text,
        "text_elements": const <Object?>[],
      },
      PluginPromptPartFilePath(:final path) => {"type": "localImage", "path": path},
      PluginPromptPartFileUrl(:final url) => {"type": "image", "url": url},
      // Inline base64 isn't a codex UserInput variant; drop with a log
      // hook if/when it shows up in real traffic.
      PluginPromptPartFileData() => null,
    };
  }

  Map<String, dynamic>? _extractThread(Object? result) {
    if (result is! Map) return null;
    final map = result.cast<String, dynamic>();
    final thread = map["thread"];
    if (thread is! Map) return null;
    return thread.cast<String, dynamic>();
  }

  PluginSessionTime? _timeFromThread(Map<String, dynamic>? thread) {
    if (thread == null) return null;
    final createdAtSeconds = thread["createdAt"];
    final updatedAtSeconds = thread["updatedAt"];
    if (createdAtSeconds is! num || updatedAtSeconds is! num) return null;
    return PluginSessionTime(
      created: (createdAtSeconds * 1000).round(),
      updated: (updatedAtSeconds * 1000).round(),
      archived: null,
    );
  }

  Future<CodexAppServerClient> _connectedClient() async {
    final ok = await _ensureConnected();
    final client = _client;
    if (!ok || client == null) {
      throw StateError("codex app-server is not connected");
    }
    return client;
  }

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async {
    final client = await _connectedClient();
    await client.request(
      method: "thread/name/set",
      params: {"threadId": sessionId, "name": title},
    );
    return PluginSession(
      id: sessionId,
      projectID: _projectCwd,
      directory: _projectCwd,
      parentID: null,
      title: title,
      time: null,
      summary: null,
    );
  }

  @override
  Future<PluginProject> renameProject({
    required String projectId,
    required String name,
  }) async {
    // The codex backend uses a single synthesised project per launch CWD,
    // so there is no per-project name to persist. Honour the contract by
    // returning a project with the requested name applied so any local
    // UI cache stays consistent.
    final base = _synthesizedProject();
    return PluginProject(id: base.id, name: name, time: base.time);
  }

  /// Removes a codex session by deleting its rollout JSONL and dropping
  /// the matching entry from `session_index.jsonl`.
  ///
  /// If the session is currently running, the active turn is interrupted
  /// first so codex isn't left writing to a file the bridge just deleted.
  /// Errors during cleanup are logged and swallowed — mobile expects
  /// best-effort delete semantics.
  @override
  Future<void> deleteSession(String sessionId) async {
    if (_activeTurnByThread.containsKey(sessionId)) {
      try {
        await abortSession(sessionId: sessionId);
      } catch (_) {
        // Continue with delete even if the abort raced.
      }
    }
    _rolloutReader.deleteSession(sessionId);
    _activeTurnByThread.remove(sessionId);
    _sessionStatuses.remove(sessionId);
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {
    try {
      final client = await _connectedClient();
      await client.request(
        method: "thread/archive",
        params: {"threadId": sessionId},
      );
    } catch (_) {
      // Best-effort — mobile DB archive state is authoritative.
    }
  }

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {
    // Codex does not manage worktrees.
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async {
    // codex-cli 0.121.0's rollout headers do not record a `forked_from`
    // field, so we have no way to reconstruct the parent→child link from
    // disk. Until codex surfaces it, return empty — the bridge contract
    // treats this as "no children known", not as an error.
    return const [];
  }

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async =>
      Map.unmodifiable(_sessionStatuses);

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async {
    final path = _rolloutReader.findRolloutPath(sessionId);
    if (path == null) return const [];
    return _rolloutReader.readMessages(path, sessionId);
  }

  @override
  Future<List<PluginAgent>> getAgents() async => const [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async =>
      _approvalRegistry?.pendingForSession(sessionId) ?? const [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({
    required String projectId,
  }) async {
    final registry = _approvalRegistry;
    if (registry == null) return const [];
    // Single-project model: every codex session belongs to the launch
    // project. Pull every known session id we've seen.
    final sessionIds = _sessionStatuses.keys.toList(growable: false);
    return registry.pendingForProject(sessionIds);
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    final registry = _approvalRegistry;
    if (registry == null) return;
    registry.replyQuestion(questionId, answers);
  }

  @override
  Future<void> rejectQuestion(String questionId) async {
    _approvalRegistry?.rejectQuestion(questionId);
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    _approvalRegistry?.replyPermission(requestId, reply);
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    return const PluginProvidersResult(providers: []);
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => const [];

  @override
  Future<void> dispose() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    await _approvalRegistry?.dispose();
    _approvalRegistry = null;
    await _client?.dispose();
    _client = null;
    await _eventBuffer.close();
  }
}

import "dart:async";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_approval_registry.dart";
import "acp_command_tracker.dart";
import "acp_event_mapper.dart";
import "acp_process_factory.dart";
import "acp_protocol.dart";
import "acp_session_loader.dart";
import "acp_stdio_client.dart";
import "acp_stdio_client_builder.dart";
import "api/acp_api.dart";
import "dispatchers/acp_turn_configuration_dispatcher.dart";
import "dispatchers/acp_turn_event_dispatcher.dart";
import "listeners/acp_approval_listener.dart";
import "listeners/acp_notification_listener.dart";
import "repositories/acp_message_repository.dart";
import "repositories/acp_notification_repository.dart";
import "repositories/acp_session_repository.dart";
import "repositories/models/acp_notification_record.dart";
import "services/acp_connection_service.dart";
import "services/acp_turn_service.dart";
import "trackers/acp_command_turn_tracker.dart";
import "trackers/acp_session_directory_tracker.dart";
import "trackers/acp_session_residency_tracker.dart";
import "trackers/acp_turn_queue_tracker.dart";

/// Base [BridgeDerivedProjectsPluginApi] implementation for any ACP (Agent
/// Client Protocol) agent driven over stdio.
///
/// ACP backends have no project concept — each session just carries a `cwd` —
/// so the bridge derives the project list from [listAllSessions] and owns all
/// project/session persistence itself; the plugin stores nothing on disk.
///
/// Concrete so a vanilla ACP harness needs only an [id] + [agentDisplayName]
/// (the "config row" case). Harnesses with quirks (e.g. Cursor's model
/// selection and `cursor/*` extensions) use the configured constructor to
/// provide their connection and approval behavior, and override product API
/// methods such as [getAgents] and [getProviders].
///
/// Unlike the codex plugin (which connects to a process listening on a ws
/// port), this owns the agent subprocess: it spawns lazily on first use and
/// reaps it on [dispose].
class AcpPlugin extends BridgeDerivedProjectsPluginApi {
  factory AcpPlugin({
    required String id,
    required String agentDisplayName,
    required AcpLaunchSpec launchSpec,
    required String launchDirectory,
    required AcpEventMapper eventMapper,
    AcpProcessFactory? processFactory,
  }) {
    final normalizedDirectory = normalizeProjectDirectory(
      directory: launchDirectory,
    );
    final clientBuilder = AcpStdioClientBuilder(
      launchSpec: launchSpec,
      processFactory: processFactory,
    );
    final liveClient = clientBuilder.build(logTag: id);
    final api = AcpApi(client: liveClient);
    final sessionRepository = AcpSessionRepository(api: api);
    final commandTracker = AcpCommandTracker();
    final commandTurnTracker = AcpCommandTurnTracker();
    final directoryTracker = AcpSessionDirectoryTracker(
      launchDirectory: normalizedDirectory,
    );
    final residencyTracker = AcpSessionResidencyTracker();
    final queueTracker = AcpTurnQueueTracker(pluginId: id);
    final eventDispatcher = AcpTurnEventDispatcher(
      eventMapper: eventMapper,
      commandTracker: commandTracker,
      commandTurnTracker: commandTurnTracker,
      residencyTracker: residencyTracker,
    );
    final connectionService = AcpConnectionService(
      client: liveClient,
      repository: sessionRepository,
      configuration: const AcpConnectionConfiguration(
        initializeRequest: AcpInitializeRequest(
          clientName: "sesori-bridge",
          clientVersion: "0.0.0",
          clientTitle: null,
          capabilityMeta: null,
        ),
        authMethodId: null,
      ),
    );
    final notificationListener = AcpNotificationListener(
      notificationRepository: AcpNotificationRepository(
        apiNotifications: api.notifications,
      ),
      eventDispatcher: eventDispatcher,
    );
    final approvalRegistry = AcpApprovalRegistry.forClient(
      client: liveClient,
      emit: eventDispatcher.emit,
      activeSessionResolver: queueTracker.resolveActiveSession,
    );
    final approvalListener = AcpApprovalListener(
      registry: approvalRegistry,
      requests: liveClient.serverRequests,
    );
    const turnConfigurationDispatcher = AcpTurnConfigurationDispatcher();
    final turnService = AcpTurnService(
      pluginId: id,
      connectionService: connectionService,
      directoryTracker: directoryTracker,
      residencyTracker: residencyTracker,
      queueTracker: queueTracker,
      commandTurnTracker: commandTurnTracker,
      eventDispatcher: eventDispatcher,
      turnConfigurationDispatcher: turnConfigurationDispatcher,
      commandFastFailWindow: const Duration(milliseconds: 100),
    );
    return AcpPlugin.configured(
      id: id,
      agentDisplayName: agentDisplayName,
      launchSpec: launchSpec,
      launchDirectory: normalizedDirectory,
      eventMapper: eventMapper,
      turnConfigurationDispatcher: turnConfigurationDispatcher,
      clientBuilder: clientBuilder,
      commandTracker: commandTracker,
      connectionService: connectionService,
      notificationListener: notificationListener,
      approvalListener: approvalListener,
      approvalRegistry: approvalRegistry,
      directoryTracker: directoryTracker,
      turnService: turnService,
    );
  }

  AcpPlugin.configured({
    required this.id,
    required this.agentDisplayName,
    required this.launchSpec,
    required String launchDirectory,
    required this.eventMapper,
    required AcpTurnConfigurationDispatcher turnConfigurationDispatcher,
    required AcpStdioClientBuilder clientBuilder,
    required AcpCommandTracker commandTracker,
    required AcpConnectionService connectionService,
    required AcpNotificationListener notificationListener,
    required AcpApprovalListener approvalListener,
    required AcpApprovalRegistry approvalRegistry,
    required AcpSessionDirectoryTracker directoryTracker,
    required AcpTurnService turnService,
  }) : launchDirectory = normalizeProjectDirectory(directory: launchDirectory),
       _turnConfigurationDispatcher = turnConfigurationDispatcher,
       _clientBuilder = clientBuilder,
       _commandTracker = commandTracker,
       _connectionService = connectionService,
       _notificationListener = notificationListener,
       _approvalListener = approvalListener,
       _approvalRegistry = approvalRegistry,
       _directoryTracker = directoryTracker,
       _turnService = turnService,
       _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>() {
    _connectionCompositionSubscription = connectionService.connections.listen((_) {
      notificationListener.attach();
      approvalListener.attach();
    });
    _turnEventSubscription = turnService.events.listen(_eventBuffer.add);
  }

  @override
  final String id;

  @override
  bool get supportsIdentityPreservingRowlessChildSessions => false;

  /// Human-facing agent name used for synthesized agents/providers.
  final String agentDisplayName;

  final AcpLaunchSpec launchSpec;

  /// Bridge launch CWD (canonicalized) — the directory the bridge seeds as an
  /// always-present project, and the fallback attribution for sessions whose
  /// own directory is unknown.
  @override
  final String launchDirectory;

  /// The live event mapper (subclasses may pass a specialized one).
  final AcpEventMapper eventMapper;

  final BufferedUntilFirstListener<BridgeSseEvent> _eventBuffer;
  final AcpTurnConfigurationDispatcher _turnConfigurationDispatcher;
  final AcpStdioClientBuilder _clientBuilder;
  final AcpCommandTracker _commandTracker;
  final AcpConnectionService _connectionService;
  final AcpNotificationListener _notificationListener;
  final AcpApprovalListener _approvalListener;
  final AcpApprovalRegistry _approvalRegistry;
  late final StreamSubscription<void> _connectionCompositionSubscription;
  final AcpSessionDirectoryTracker _directoryTracker;
  final AcpTurnService _turnService;
  late final StreamSubscription<BridgeSseEvent> _turnEventSubscription;

  /// Snapshot of the agent's advertised slash commands, fed by the
  /// notification listener and served by [getCommands].
  /// Emits after each successful (re)connect — including a lazy reconnect that
  /// follows [resetConnectionAfterExit] — so the lifecycle wrapper can re-arm
  /// its exit watch on the new client and flip back to ready. Broadcast (no
  /// buffering): the initial connect, driven by the wrapper directly, is not a
  /// subscriber so it is not double-handled.
  Stream<void> get onConnected => _connectionService.connections;

  /// The session to attribute a mid-turn server request that carries no
  /// `sessionId` of its own (see [AcpApprovalRegistry.resolveSessionId]).
  ///
  /// Precise when exactly one turn is in flight. With concurrent turns on
  /// multiple sessions ACP gives no request→turn correlation, so the most
  /// recent dispatch is used and the ambiguity is logged. With no turn in
  /// flight, the last dispatched turn's session is returned (boundary case).
  String? get activeTurnSessionId => _turnService.activeTurnSessionId;

  /// Whether this connection's agent rejected an *unfiltered* `session/list`
  /// (the ACP spec's global enumeration — `cwd` is only a filter). Remembered
  /// per connection so a non-compliant agent is asked once, not on every
  /// enumeration; reset on respawn since a replacement process may comply.
  bool _bareSessionListUnsupported = false;

  /// Delegates config capture to the composed turn-configuration dispatcher.
  void captureSessionConfig(
    AcpNewSessionResult result, {
    String? sessionId,
    bool fromNewSession = false,
  }) => _turnConfigurationDispatcher.captureSessionConfig(
    result,
    sessionId: sessionId,
    fromNewSession: fromNewSession,
  );

  // --- Protected accessors for subclasses ---

  AcpStdioClient? get client => _connectionService.current?.client;
  AcpInitializeResult? get initializeResult => _connectionService.current?.initializeResult;
  void emitEvent(BridgeSseEvent event) => _eventBuffer.add(event);

  // --- BridgePluginApi ---

  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;

  Future<bool> ensureConnected() async {
    try {
      await _connectionService.ensureConnected();
      return true;
    } on Object {
      return false;
    }
  }

  Future<AcpSessionRepository> _connectedRepository() async {
    return (await _connectionService.ensureConnected()).repository;
  }

  /// Tears down the cached ACP connection after the agent subprocess exits, so
  /// the next [ensureConnected] spawns a fresh agent instead of writing to the
  /// dead process. The lifecycle wrapper calls this from its exit watch when an
  /// unexpected exit flips the plugin to degraded; without it the cached
  /// `_connectFuture`/`_client` keep reporting a successful connection and
  /// requests are written to the exited process until they fail or time out.
  ///
  /// Resident sessions are forgotten: the replacement process holds no sessions
  /// until they are re-created or resumed via `session/load`. The event channel
  /// is left intact — the plugin stays alive, only the connection is reset.
  /// Never throws.
  Future<void> resetConnectionAfterExit() async {
    _bareSessionListUnsupported = false;
    _commandTracker.clear();
    _turnService.resetConnection();
    try {
      await _approvalListener.reset();
      await _connectionService.reset();
    } on Object catch (e, st) {
      Log.w("[$id] failed to reset ACP connection", e, st);
    }
  }

  @override
  Future<bool> healthCheck() async {
    try {
      return await ensureConnected();
    } catch (_) {
      return false;
    }
  }

  /// Enumerates every session the agent will report, by unioning:
  ///
  ///  - one *unfiltered* `session/list` (per the ACP spec `cwd` is only a
  ///    filter), so sessions living in directories the bridge never recorded
  ///    (e.g. created via the agent's own CLI) still surface — matching how
  ///    codex's global rollout index behaves; and
  ///  - a `session/list {cwd}` scan per directory — the bridge's
  ///    [knownDirectories] (stored project paths and worktree paths), the
  ///    launch directory, and every directory this run has attributed a
  ///    session to — because the cwd-filtered form is the shape verified
  ///    against live cursor-agent.
  ///
  /// Fail-soft: an agent that rejects the unfiltered form is remembered for
  /// this connection and not asked again; a failed per-directory scan is
  /// logged and skipped so one bad directory cannot empty the enumeration; an
  /// unreachable agent yields `[]` so the bridge still serves its stored
  /// project rows.
  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    final AcpSessionRepository repository;
    try {
      repository = await _connectedRepository();
    } on Object catch (error) {
      Log.w("[$id] listAllSessions: agent unreachable; serving no sessions", error);
      return const [];
    }
    if (!(_connectionService.current?.initializeResult.agentCapabilities.listSessions ?? false)) return const [];

    _directoryTracker.addHints(knownDirectories);
    final directories = _directoryTracker.scanDirectories;

    final sessionsById = <String, PluginSession>{};
    // Session ids whose directory came only from the launch-directory fallback
    // (the unfiltered list returned them without a `cwd`). A later cwd-scoped
    // scan that returns the same session knows its real directory, so it must
    // replace the fallback attribution rather than be dropped by dedup.
    final fallbackAttributed = <String>{};
    if (!_bareSessionListUnsupported) {
      try {
        for (final info in await _listSessionPages(repository, cwd: null)) {
          if (info.sessionId.isEmpty) continue;
          sessionsById[info.sessionId] = _toPluginSession(
            info,
            fallbackDirectory: launchDirectory,
            fallbackIsAuthoritative: false,
          );
          final hasCwd = info.cwd != null && info.cwd!.trim().isNotEmpty;
          if (!hasCwd) fallbackAttributed.add(info.sessionId);
        }
      } on Object catch (error) {
        // Only a genuine "unsupported RPC" (method-not-found / invalid-params)
        // means this agent will never serve the unfiltered form — memoize that.
        // A transient failure (timeout, process-exit race, other agent error)
        // must NOT be memoized, or a one-off blip would permanently drop the
        // only path that finds sessions outside the bridge's hinted directories.
        if (error is AcpRpcException && (error.code == -32601 || error.code == -32602)) {
          _bareSessionListUnsupported = true;
          Log.d("[$id] unfiltered session/list unsupported (code ${error.code}); per-directory scans only");
        } else {
          Log.d("[$id] unfiltered session/list failed transiently; will retry next enumeration: $error");
        }
      }
    }
    for (final directory in directories) {
      try {
        for (final info in await _listSessionPages(repository, cwd: directory)) {
          if (info.sessionId.isEmpty) continue;
          // A cwd-scoped hit is authoritative for the session's directory, so
          // it fills a session not seen yet AND repairs one the unfiltered
          // pass could only attribute to the launch fallback.
          if (!sessionsById.containsKey(info.sessionId) || fallbackAttributed.remove(info.sessionId)) {
            sessionsById[info.sessionId] = _toPluginSession(
              info,
              fallbackDirectory: directory,
              fallbackIsAuthoritative: true,
            );
          }
        }
      } on Object catch (error, stack) {
        Log.w("[$id] session/list failed for $directory; skipping", error, stack);
      }
    }
    return sessionsById.values.toList(growable: false);
  }

  @override
  Future<List<PluginSession>> getSessions(
    String projectId, {
    int? start,
    int? limit,
  }) async {
    final AcpSessionRepository repository;
    try {
      repository = await _connectedRepository();
    } on Object catch (error) {
      Log.w("[$id] getSessions: agent unreachable; serving no sessions", error);
      return const [];
    }
    if (!(_connectionService.current?.initializeResult.agentCapabilities.listSessions ?? false)) return const [];
    final target = normalizeProjectDirectory(directory: projectId);
    try {
      final mapped = [
        for (final info in await _listSessionPages(repository, cwd: target))
          _toPluginSession(
            info,
            fallbackDirectory: target,
            fallbackIsAuthoritative: true,
          ),
      ];
      final from = start ?? 0;
      if (from >= mapped.length) return const [];
      final until = limit == null ? mapped.length : (from + limit).clamp(0, mapped.length);
      return mapped.sublist(from, until);
    } on Object catch (error, stack) {
      Log.w("[$id] session/list failed for $target; serving no sessions", error, stack);
      return const [];
    }
  }

  /// Fetches the full `session/list` result for [cwd] (null = unfiltered),
  /// following `nextCursor` pagination. Bounded so an agent that never
  /// exhausts its cursor cannot spin the bridge forever.
  ///
  /// Only a **first-page** failure propagates: it is authoritative for whether
  /// the form is supported (so the caller can memoize `-32601`/`-32602`). A
  /// later-page failure means the form works but pagination hit a snag — the
  /// pages gathered so far are returned rather than discarding a proven-good
  /// first page (and the caller must not memoize a mid-pagination error as
  /// "unsupported").
  Future<List<AcpSessionInfo>> _listSessionPages(
    AcpSessionRepository repository, {
    required String? cwd,
  }) async {
    const maxPages = 50;
    final infos = <AcpSessionInfo>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final AcpSessionListResult result;
      try {
        result = await repository.listSessions(
          directory: cwd,
          cursor: cursor,
        );
      } on Object catch (error, stack) {
        if (page == 0) rethrow;
        Log.w(
          "[$id] session/list page $page for ${cwd ?? "(all)"} failed; "
          "returning ${infos.length} gathered so far",
          error,
          stack,
        );
        break;
      }
      infos.addAll(result.sessions);
      final next = result.nextCursor;
      if (next == null || next.isEmpty) break;
      cursor = next;
    }
    return infos;
  }

  PluginSession _toPluginSession(
    AcpSessionInfo info, {
    required String fallbackDirectory,
    required bool fallbackIsAuthoritative,
  }) {
    // The session belongs to its own cwd, canonicalized so it matches the
    // project id the bridge derives from the same value. A missing OR blank cwd
    // falls back to the directory that was scanned — the same `trim().isNotEmpty`
    // guard the caller uses to flag fallback attribution, so the two stay
    // consistent (a bare `?? ` would let `""` through to the process cwd).
    final rawCwd = info.cwd;
    final hasCwd = rawCwd != null && rawCwd.trim().isNotEmpty;
    final directory = normalizeProjectDirectory(directory: hasCwd ? rawCwd : fallbackDirectory);
    final directoryIsAuthoritative = hasCwd || fallbackIsAuthoritative;
    final id = info.sessionId;
    // A cwd-scoped response is authoritative even when its item omits cwd. Only
    // the unfiltered launch fallback remains eligible for a stored bridge prime
    // to repair.
    if (id.isNotEmpty) {
      if (directoryIsAuthoritative) {
        _directoryTracker.recordAuthoritative(sessionId: id, directory: directory);
      }
      eventMapper.setSessionProject(
        id,
        _directoryTracker.containsSession(id) ? _directoryTracker.directoryFor(id) : directory,
      );
      eventMapper.setSessionSnapshot(
        sessionId: id,
        title: info.title,
        createdMs: info.updatedAtMs,
        updatedMs: info.updatedAtMs,
      );
    }
    final ts = info.updatedAtMs;
    return PluginSession(
      id: id,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: info.title,
      time: ts == null ? null : PluginSessionTime(created: ts, updated: ts, archived: null),
    );
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async =>
      // Served from the `available_commands_update` snapshot — ACP advertises
      // commands via that notification, not a request endpoint.
      _commandTracker.commands;

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    final repository = await _connectedRepository();
    // The session lives in its own cwd (for a dedicated session that is the
    // worktree path). Canonicalized so it matches the project id the bridge
    // derives from it; the bridge's stored row folds a worktree session back
    // under the project the user opened.
    final canonicalDirectory = normalizeProjectDirectory(directory: directory);
    final session = await repository.newSession(directory: directory);
    if (session.sessionId.isEmpty) {
      throw StateError("session/new response missing sessionId");
    }
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    _directoryTracker.recordAuthoritative(
      sessionId: session.sessionId,
      directory: canonicalDirectory,
    );
    eventMapper.setSessionProject(session.sessionId, canonicalDirectory);
    // Seed the snapshot so a title event during the creation race (before the
    // bridge has a stored row to enrich from) still carries a sane time.
    eventMapper.setSessionSnapshot(
      sessionId: session.sessionId,
      title: null,
      createdMs: createdAt,
      updatedMs: createdAt,
    );
    // A session/new response is the authoritative source of the backend's
    // new-session default model/mode.
    captureSessionConfig(session, sessionId: session.sessionId, fromNewSession: true);
    // session/new leaves the session resident in the agent process.
    _turnService.registerSession(
      sessionId: session.sessionId,
      resident: true,
    );
    if (parts.isEmpty) {
      // No first turn to carry the selection: apply it now so the session's
      // model/mode are in place for whichever turn comes first later.
      await _turnConfigurationDispatcher.apply(
        repository: repository,
        sessionId: session.sessionId,
        model: model,
        variant: variant,
        agent: agent,
        failOnError: false,
      );
    } else {
      // A fresh session has an empty chain, so this dispatches immediately;
      // the selection is applied inside the turn like every other prompt.
      _turnService.enqueuePrompt(
        sessionId: session.sessionId,
        blocks: _promptPartsToContentBlocks(parts),
        model: model,
        variant: variant,
        agent: agent,
      );
    }
    return PluginSession(
      id: session.sessionId,
      projectID: canonicalDirectory,
      directory: canonicalDirectory,
      parentID: parentSessionId,
      title: null,
      time: PluginSessionTime(created: createdAt, updated: createdAt, archived: null),
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
    // Acceptance gate: an unreachable agent fails the send itself; the turn
    // re-resolves the client at dispatch time (see [_runTurn]).
    await _connectedRepository();
    eventMapper.mapSentPrompt(sessionId: sessionId, parts: parts).forEach(_eventBuffer.add);
    _turnService.enqueuePrompt(
      sessionId: sessionId,
      blocks: _promptPartsToContentBlocks(parts),
      model: model,
      variant: variant,
      agent: agent,
    );
  }

  @override
  Future<PluginCommandDispatch> sendCommand({
    required String sessionId,
    required String invocationId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => _turnService.sendCommand(
    sessionId: sessionId,
    invocationId: invocationId,
    command: command,
    arguments: arguments,
    variant: variant,
    agent: agent,
    model: model,
  );

  /// The directory a session should be loaded/operated in — its own canonical
  /// directory when known, else the launch directory.
  String _directoryForSession(String sessionId) => _directoryTracker.directoryFor(sessionId);

  @override
  void primeSessionDirectory({required String sessionId, required String directory}) {
    if (sessionId.isEmpty || directory.trim().isEmpty) return;
    final effectiveDirectory = _directoryTracker.prime(
      sessionId: sessionId,
      directory: directory,
    );
    eventMapper.setSessionProject(sessionId, effectiveDirectory);
  }

  List<AcpContentBlock> _promptPartsToContentBlocks(
    List<PluginPromptPart> parts,
  ) => parts.map(_promptPartToContentBlock).whereType<AcpContentBlock>().toList(growable: false);

  AcpContentBlock? _promptPartToContentBlock(PluginPromptPart part) {
    return switch (part) {
      PluginPromptPartText(:final text) => AcpTextContentBlock(text: text),
      PluginPromptPartFilePath(:final path, :final filename) => AcpResourceLinkContentBlock(
        // Uri.file encodes spaces and Windows drive/backslash paths; plain
        // "file://$path" interpolation emits an invalid uri (e.g.
        // `file://C:\a b.png`) that the agent rejects or ignores.
        uri: Uri.file(path).toString(),
        name: filename ?? p.basename(path),
      ),
      PluginPromptPartFileUrl(:final url, :final filename) => AcpResourceLinkContentBlock(
        uri: url,
        name: filename ?? url,
      ),
      // ACP defines inline image/audio content blocks (base64 `data` +
      // `mimeType`); map those so a phone attachment is not silently lost.
      // Other mime types have no ACP inline block and are dropped.
      PluginPromptPartFileData(:final mime, :final base64) => _inlineContentBlock(mime, base64),
    };
  }

  AcpContentBlock? _inlineContentBlock(String mime, String base64) {
    final type = switch (mime.split("/").first.toLowerCase()) {
      "image" => AcpInlineContentType.image,
      "audio" => AcpInlineContentType.audio,
      _ => null,
    };
    if (type == null) return null;
    return AcpInlineContentBlock(
      type: type,
      mimeType: mime,
      data: base64,
    );
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    await _turnService.abortSession(sessionId: sessionId);
    // ACP requires the client to resolve any permission/question the cancelled
    // turn was blocked on; otherwise the agent keeps waiting on that JSON-RPC
    // request and the phone shows a stale prompt.
    _approvalRegistry.cancelForSession(sessionId);
  }

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async {
    // ACP has no standard rename; honour the contract optimistically so any
    // local UI cache stays consistent. The mobile DB is authoritative.
    final directory = _directoryForSession(sessionId);
    return PluginSession(
      id: sessionId,
      projectID: directory,
      directory: directory,
      parentID: null,
      title: title,
      time: null,
    );
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (_turnService.pendingTurnCount(sessionId) > 0) {
      await abortSession(sessionId: sessionId);
    }
    _directoryTracker.forgetSession(sessionId);
    _turnService.forgetSession(sessionId);
    // Drops the session's project attribution plus all other per-session mapper
    // caches (model, turn counters, started parts, live tools) so nothing
    // accumulates for a deleted session.
    eventMapper.forgetSession(sessionId);
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {
    // Best-effort — mobile DB archive state is authoritative.
  }

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {
    // ACP agents don't manage worktrees.
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => const [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => _turnService.sessionStatuses;

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId, {
    required List<PluginCommandInvocationContext> acceptedCommands,
  }) async {
    // After a restart this replay can be the FIRST ACP call for a stored
    // worktree session (session-detail loads messages + detail in parallel,
    // and the messages handler hits the plugin directly), so its directory may
    // be unknown and the load below would run in the launch directory. Warm
    // attribution first — same fail-soft enumeration the resume path uses.
    if (!_directoryTracker.containsSession(sessionId)) {
      await listAllSessions(knownDirectories: const {});
    }
    // History via `session/load` replay on a dedicated short-lived client so
    // replayed updates don't interleave with the live session's stream.
    final replayClient = _clientBuilder.build(
      logTag: "$id-replay",
    );
    final collector = AcpReplayCollector(
      sessionId: sessionId,
      agentId: agentDisplayName,
      modelId: eventMapper.modelForSession(sessionId),
      providerId: eventMapper.providerForSession(sessionId),
      // Reclassify a halt notice (e.g. Cursor's account/plan gate) the same way
      // the live stream does, so reloaded history renders it identically.
      haltClassifier: eventMapper.classifyHaltNotice,
    );
    StreamSubscription<AcpNotificationRecord>? sub;
    try {
      await replayClient.connect();
      final replayApi = AcpApi(client: replayClient);
      final replayNotificationRepository = AcpNotificationRepository(
        apiNotifications: replayApi.notifications,
      );
      final replayRepository = AcpSessionRepository(
        api: replayApi,
      );
      final replayInit = await _connectionService.initializeRepository(
        replayRepository,
      );
      if (!replayInit.agentCapabilities.loadSession) {
        // History is genuinely unavailable on this agent — an empty thread,
        // not a failure: the session must stay usable for new prompts.
        return const [];
      }
      if (!replayClient.isConnected) {
        // The replay agent died right after the handshake — a failure, not an
        // empty thread (wrapped into the typed failure below).
        throw StateError("replay agent exited during initialization");
      }
      var received = 0;
      BridgeSseSessionsUpdated? deferredCommandRefresh;
      sub = replayNotificationRepository.notifications.listen((record) {
        if (record is AcpSessionNotificationRecord) {
          received++;
          collector.consume(record);
          if (record is AcpAvailableCommandsChangedRecord) {
            _commandTracker.consume(record);
            final refreshes = eventMapper.map(record).whereType<BridgeSseSessionsUpdated>();
            if (refreshes.isNotEmpty) deferredCommandRefresh = refreshes.last;
          }
        }
      });
      final AcpNewSessionResult result;
      try {
        result = await replayRepository.loadSession(
          sessionId: sessionId,
          directory: _directoryForSession(sessionId),
        );
      } on AcpRpcException catch (error, stackTrace) {
        if (error.code == -32601) {
          // Method-not-found conclusively means this agent cannot serve
          // history despite advertising the capability. Invalid params is an
          // operation failure and is deliberately not degraded to an empty
          // thread.
          Log.w(
            "[$id] session/load is unsupported despite the advertised capability",
            error,
            stackTrace,
          );
          final commandRefresh = deferredCommandRefresh;
          if (commandRefresh != null) _eventBuffer.add(commandRefresh);
          return const [];
        }
        // Any other RPC error is a genuine load failure — wrapped typed below.
        final commandRefresh = deferredCommandRefresh;
        if (commandRefresh != null) _eventBuffer.add(commandRefresh);
        rethrow;
      }
      // The load result also carries the model/mode catalog (and the loaded
      // session's current model) — capture it so the picker is populated and
      // replayed messages are stamped with the session's real model.
      captureSessionConfig(result, sessionId: sessionId);
      // The ACP spec replays the whole thread via `session/update` BEFORE the
      // `session/load` response resolves, but cursor-agent streams later turns
      // AFTER it. Drain until the replay stream goes quiet so multi-turn history
      // is captured in full, bounded so a chatty agent can't hang the request.
      await _drainReplay(() => received);
      final commandRefresh = deferredCommandRefresh;
      if (commandRefresh != null) _eventBuffer.add(commandRefresh);
      collector.modelId = eventMapper.modelForSession(sessionId);
      collector.providerId = eventMapper.providerForSession(sessionId);
      return const AcpMessageRepository().mapHistory(
        sessionId: sessionId,
        agentId: agentDisplayName,
        modelId: collector.modelId,
        providerId: collector.providerId,
        records: collector.build(),
        acceptedCommands: acceptedCommands,
        knownCommandNames: _commandTracker.commands.map((command) => command.name).toSet(),
      );
    } on Object catch (error, stackTrace) {
      // A broken replay (connect/init/auth/load failure) must stay
      // distinguishable from a genuinely empty thread: surface it as a typed
      // failure (the bridge router maps it to a 502 and the phone renders a
      // retry state) instead of swallowing it into an empty list.
      Error.throwWithStackTrace(
        PluginOperationException(
          "session/load history replay",
          message: "history replay for $sessionId failed",
          cause: error,
        ),
        stackTrace,
      );
    } finally {
      try {
        await sub?.cancel();
      } on Object catch (e, st) {
        Log.w("[$id] failed to cancel replay subscription", e, st);
      }
      try {
        await replayClient.dispose();
      } on Object catch (e, st) {
        Log.w("[$id] failed to dispose replay client", e, st);
      }
    }
  }

  /// Waits until the replay `session/update` stream goes quiet — no new
  /// notification within one [quiet] window — bounded by [max]. [count] returns
  /// the running number of replay notifications seen so far.
  Future<void> _drainReplay(
    int Function() count, {
    Duration quiet = const Duration(milliseconds: 250),
    Duration max = const Duration(seconds: 6),
  }) async {
    var elapsed = Duration.zero;
    var last = -1;
    while (elapsed < max) {
      final snapshot = count();
      if (snapshot == last) return;
      last = snapshot;
      await Future<void>.delayed(quiet);
      elapsed += quiet;
    }
  }

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    final modelId = eventMapper.currentModelId;
    return [
      PluginAgent(
        name: id,
        description: "$agentDisplayName session",
        model: modelId == null
            ? null
            : PluginAgentModel(
                modelID: modelId,
                providerID: eventMapper.currentProviderId ?? id,
                variant: null,
              ),
        mode: PluginAgentMode.primary,
        hidden: false,
      ),
    ];
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    final modelId = eventMapper.currentModelId;
    if (modelId == null) return const PluginProvidersResult(providers: []);
    final providerId = eventMapper.currentProviderId ?? id;
    return PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: providerId,
          name: agentDisplayName,
          authType: PluginProviderAuthType.unknown,
          models: [
            PluginModel(
              id: modelId,
              name: modelId,
              variants: const [],
              family: null,
              isAvailable: true,
              releaseDate: null,
            ),
          ],
          defaultModelID: modelId,
        ),
      ],
    );
  }

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async => _approvalRegistry.pendingForSession(sessionId);

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({
    required String sessionId,
  }) async => _approvalRegistry.pendingPermissionsForSession(sessionId);

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({
    required String projectId,
  }) async {
    final registry = _approvalRegistry;
    // Scope to the sessions attributed to this project so a pending question
    // in one project doesn't surface under every other. The bridge merges in
    // this plugin's worktree sessions itself via its stored attribution rows.
    final target = normalizeProjectDirectory(directory: projectId);
    final sessionIds = _turnService.sessionStatuses.keys
        .where((sessionId) => _directoryForSession(sessionId) == target)
        .toList(growable: false);
    return registry.pendingForProject(sessionIds);
  }

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    _approvalRegistry.replyQuestion(questionId, answers);
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    // The registry is keyed by the bridge question id; it already knows the
    // session (and clears the pending entry, so awaiting-input drops), so the
    // sessionId argument is not needed here.
    _approvalRegistry.rejectQuestion(questionId);
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    _approvalRegistry.replyPermission(requestId, reply);
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    final registry = _approvalRegistry;

    // Surface a session only when it has live activity: the agent is running
    // (a `session/prompt` turn is in flight) or it is blocked awaiting a user
    // answer/permission. Idle sessions are not "active" and are dropped, which
    // also means a fully idle agent yields an empty summary (no project row) —
    // matching the OpenCode plugin's "only active worktrees" contract.
    //
    // ACP sessions are flat: this plugin tracks no parent/child relationships,
    // so `childSessionIds` is always empty, and it has no retry concept, so
    // `isRetrying` is always false.
    // Group active sessions under the project (directory) each belongs to, so
    // the per-project activity badge lands on the right project — sessions can
    // live in different opened directories, not just the launch CWD.
    final byProject = <String, List<PluginActiveSession>>{};
    for (final sessionId in _turnService.sessionStatuses.keys) {
      // A session with any unfinished turn (running or queued behind one)
      // counts as running, so it stays active until its last turn settles.
      final running = _turnService.isRunning(sessionId);
      final awaiting = registry.hasPendingInput(sessionId);
      if (!running && !awaiting) continue;
      (byProject[_directoryForSession(sessionId)] ??= []).add(
        PluginActiveSession(
          id: sessionId,
          mainAgentRunning: running,
          awaitingInput: awaiting,
          isRetrying: false,
          childSessionIds: const [],
        ),
      );
    }
    if (byProject.isEmpty) return const [];

    return [
      for (final entry in byProject.entries) PluginProjectActivitySummary(id: entry.key, activeSessions: entry.value),
    ];
  }

  @override
  Future<void> dispose() async {
    // Each teardown step is isolated so a failure in one (e.g. a hung
    // subscription) cannot skip a later one (e.g. reaping the agent
    // subprocess). dispose() must not throw — log and continue.
    try {
      await _turnService.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose turn service", e, st);
    }
    try {
      await _turnEventSubscription.cancel();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel turn-event subscription", e, st);
    }
    try {
      await _connectionCompositionSubscription.cancel();
    } on Object catch (e, st) {
      Log.w("[$id] failed to cancel connection-composition subscription", e, st);
    }
    try {
      await _notificationListener.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose notification listener", e, st);
    }
    try {
      await _approvalListener.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose approval listener", e, st);
    }
    try {
      await _connectionService.dispose();
    } on Object catch (e, st) {
      Log.w("[$id] failed to dispose connection service", e, st);
    }
    try {
      await _eventBuffer.close();
    } on Object catch (e, st) {
      Log.w("[$id] failed to close event buffer", e, st);
    }
  }
}

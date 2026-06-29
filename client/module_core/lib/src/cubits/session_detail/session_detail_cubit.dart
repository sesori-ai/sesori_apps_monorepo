import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../logging/logging.dart";
import "../../platform/lifecycle_source.dart";
import "../../platform/notification_canceller.dart";
import "../../repositories/permission_repository.dart";
import "../../repositories/session_repository.dart";
import "../../services/session_detail_load_service.dart";
import "../../services/session_viewing_service.dart";
import "../../utils/model_filter/default_model_selector.dart";
import "prompt_send_queue.dart";
import "queued_session_submission.dart";
import "session_detail_state.dart";
import "streaming_text_buffer.dart";

class SessionDetailCubit extends Cubit<SessionDetailState> {
  final SessionDetailLoadService _loadService;
  final SessionRepository _sessionRepository;
  final ConnectionService _connectionService;
  final PermissionRepository _permissionRepository;
  final SessionViewingService _sessionViewingService;
  final LifecycleSource _lifecycleSource;
  static const _defaultModelSelector = DefaultModelSelector();
  final String _sessionId;
  final String _projectId;
  final NotificationCanceller _notificationCanceller;
  final FailureReporter _failureReporter;
  final PromptSendQueue _promptQueue = PromptSendQueue();
  bool _isSending = false;

  late final StreamSubscription<SesoriSessionEvent> _eventSubscription;
  late final StreamSubscription<SseEvent> _globalEventSubscription;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late final StreamSubscription<void> _staleSubscription;
  late final StreamSubscription<LifecycleState> _lifecycleSubscription;
  bool _wasPaused = false;
  int _nextLoadId = 0;
  // Ids of _loadMessages calls currently executing. A set (not a counter) so
  // overlapping loads stay individually identifiable for the resume-defer logic
  // below; non-empty means at least one load is in flight.
  final Set<int> _activeLoadIds = <int>{};
  bool get _loadInFlight => _activeLoadIds.isNotEmpty;
  // Ids of loads that were in flight when the app resumed from background. Such a
  // load's snapshot may predate activity that arrived while hidden, so it must
  // refresh before declaring the view instead of acting on a possibly-stale
  // result. Tracked per-load (not a single bool) so a resume during overlapping
  // loads defers EACH in-flight load, and the defer can't leak into a later
  // fresh load that started after the resume.
  final Set<int> _resumedLoadIds = <int>{};
  late final StreamingTextBuffer _streamingBuffer;
  Future<void>? _activeRefresh;
  int _refreshGeneration = 0;
  bool _pendingForcedRefresh = false;
  bool _needsStaleRefresh = false;
  bool _needsFreshRefreshOnReconnect = false;
  bool _wasConnected = false;
  bool _waitingForConnection = false;

  /// Pending session-scoped SSE events that arrived while the cubit was in
  /// [SessionDetailLoading] or [SessionDetailFailed] state. Replayed once the
  /// state transitions to [SessionDetailLoaded].
  final List<SesoriSessionEvent> _pendingSessionEvents = [];

  /// Pending global SSE events that arrived while the cubit was in
  /// [SessionDetailLoading] or [SessionDetailFailed] state. Replayed once the
  /// state transitions to [SessionDetailLoaded].
  final List<SseEvent> _pendingGlobalEvents = [];

  /// Fires the [SesoriQuestionAsked] whenever a new question arrives, so the
  /// screen can auto-open the question modal.
  final StreamController<SesoriQuestionAsked> _questionStream = StreamController.broadcast();
  Stream<SesoriQuestionAsked> get questionStream => _questionStream.stream;

  /// Fires the [SesoriPermissionAsked] whenever a new permission arrives, so the
  /// screen can auto-open the permission modal.
  final StreamController<SesoriPermissionAsked> _permissionStream = StreamController.broadcast();
  Stream<SesoriPermissionAsked> get permissionStream => _permissionStream.stream;

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  SessionDetailCubit(
    ConnectionService connectionService, {
    required SessionDetailLoadService loadService,
    required SessionRepository promptDispatcher,
    required PermissionRepository permissionRepository,
    required SessionViewingService sessionViewingService,
    required LifecycleSource lifecycleSource,
    required String sessionId,
    required String projectId,
    required NotificationCanceller notificationCanceller,
    required FailureReporter failureReporter,
  }) : _loadService = loadService,
       _sessionRepository = promptDispatcher,
       _connectionService = connectionService,
       _permissionRepository = permissionRepository,
       _sessionViewingService = sessionViewingService,
       _lifecycleSource = lifecycleSource,
       _sessionId = sessionId,
       _projectId = projectId,
       _notificationCanceller = notificationCanceller,
       _failureReporter = failureReporter,
       super(const SessionDetailState.loading()) {
    _streamingBuffer = StreamingTextBuffer(onFlush: _emitStreamingSnapshot);
    // Seed the connection state so the BehaviorSubject's immediate replay isn't
    // treated as a reconnect transition.
    _wasConnected = _connectionService.currentStatus is ConnectionConnected;
    _eventSubscription = _connectionService.sessionEvents(_sessionId).listen(_handleEvent);
    _globalEventSubscription = _connectionService.events.listen(_handleGlobalEvent);
    _connectionStatusSubscription = _connectionService.status.listen(_onConnectionStatusChanged);
    _staleSubscription = _connectionService.dataMayBeStale.listen((_) => _onDataMayBeStale());
    _lifecycleSubscription = _lifecycleSource.lifecycleStateStream.listen(_onLifecycleChanged);
    _loadMessages(isReload: false);
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadMessages({required bool isReload}) async {
    emit(const SessionDetailState.loading());
    final loadId = _nextLoadId++;
    _activeLoadIds.add(loadId);
    final SessionDetailLoadResult result;
    try {
      result = isReload
          ? await _loadService.reload(sessionId: _sessionId, projectId: _projectId)
          : await _loadService.load(sessionId: _sessionId, projectId: _projectId);
    } finally {
      _activeLoadIds.remove(loadId);
    }
    if (isClosed) return;

    // Did the app resume while THIS specific load was in flight? If so its
    // snapshot may predate activity that arrived while hidden, so refresh before
    // declaring the view. Scoped to this load's id (not a shared bool) so an
    // overlapping load carries its own defer and a Failed/WaitingForConnection
    // outcome can't leak the defer into a later fresh load. The
    // WaitingForConnection branch intentionally does NOT read this: it produced
    // no snapshot, and the retry it starts begins after the resume, so that
    // retry is genuinely fresh and declares the view normally.
    final resumedDuringThisLoad = _resumedLoadIds.remove(loadId);

    switch (result) {
      case SessionDetailLoadResultLoaded(:final snapshot):
        _waitingForConnection = false;
        emit(_buildLoadedState(snapshot: snapshot));
        if (resumedDuringThisLoad) {
          // The app was backgrounded/resumed while this load was in flight, so
          // the response may predate activity that arrived while hidden. Don't
          // declare the view on this possibly-stale snapshot; refresh first and
          // let the refresh re-assert the view once fresh content renders (or
          // defer to the reconnect path when offline).
          if (_isConnected) {
            _forceFreshRefresh();
          } else {
            _needsStaleRefresh = true;
            _needsFreshRefreshOnReconnect = true;
          }
        } else {
          // Declare that the user is now viewing this session only after the
          // transcript has actually loaded — otherwise a load that fails or stays
          // in the waiting-for-connection path would mark the session read (and
          // clear its bold globally) while the user only saw a loading/error state.
          _sessionViewingService.setViewingSession(_sessionId);
        }
        _drainPendingEvents();
        _tryDrainQueue();
      case SessionDetailLoadResultWaitingForConnection():
        _waitingForConnection = true;
        if (_connectionService.currentStatus is ConnectionConnected) {
          _waitingForConnection = false;
          unawaited(_loadMessages(isReload: true));
        }
      case SessionDetailLoadResultFailed(:final error, :final stackTrace):
        _waitingForConnection = false;
        _pendingSessionEvents.clear();
        _pendingGlobalEvents.clear();
        loge("Session detail load failed", error, stackTrace);
        emit(
          SessionDetailState.failed(
            reason: error is ApiError ? error.remoteFailureReason : RemoteFailureReason.unknown,
          ),
        );
    }
  }

  Future<void> reload() => _loadMessages(isReload: true);

  void _silentRefresh() {
    if (state is! SessionDetailLoaded) return;
    if (_activeRefresh != null) return;
    _startRefreshChain(Future<void>.value());
  }

  /// Like [_silentRefresh] but guarantees a refresh that started *after* this
  /// call — it will not coalesce onto an already-in-flight request that may have
  /// begun before the app was backgrounded (and thus would render a snapshot
  /// missing activity that arrived while hidden). Used on resume so the view is
  /// only re-asserted after genuinely fresh content. If called repeatedly while
  /// a chain is in flight, exactly one additional refresh is appended (a pending
  /// flag), so rapid pause/resume can't stack many redundant refreshes.
  void _forceFreshRefresh() {
    if (state is! SessionDetailLoaded) return;
    final inFlight = _activeRefresh;
    if (inFlight == null) {
      _startRefreshChain(Future<void>.value());
      return;
    }
    // A chain is already running; request exactly one fresh refresh after it.
    _pendingForcedRefresh = true;
  }

  /// Starts a refresh chain after [precursor] completes and takes ownership of
  /// [_activeRefresh]. A generation token ensures only the chain that currently
  /// owns [_activeRefresh] clears it on completion — a superseding chain won't
  /// be nulled out from under by an older chain's completion (which would let
  /// [_silentRefresh] start a concurrent refresh and break single-flight).
  void _startRefreshChain(Future<void> precursor) {
    final token = ++_refreshGeneration;
    _activeRefresh = precursor.then((_) => _doSilentRefresh()).whenComplete(() {
      if (_refreshGeneration != token) return; // superseded by a newer chain
      _activeRefresh = null;
      if (_pendingForcedRefresh && !isClosed && state is SessionDetailLoaded) {
        _pendingForcedRefresh = false;
        _startRefreshChain(Future<void>.value());
      } else {
        _pendingForcedRefresh = false;
      }
    });
  }

  Future<void> _doSilentRefresh() async {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    emit(current.copyWith(isRefreshing: true, queuedMessages: _promptQueue.items));

    try {
      final result = await _loadService.reload(sessionId: _sessionId, projectId: _projectId);
      if (isClosed) return;

      switch (result) {
        case SessionDetailLoadResultLoaded(:final snapshot):
          _waitingForConnection = false;
          final latestAssistant = _latestAssistantMessage(snapshot.messages);
          final childIds = snapshot.childSessions.map((c) => c.id).toSet();
          final childStatuses = Map<String, SessionStatus>.fromEntries(
            snapshot.statuses.entries.where((e) => childIds.contains(e.key)),
          );
          final availableAgents = snapshot.agents
              .whereType<AgentInfo>()
              .where((a) => !a.hidden && a.mode != AgentMode.subagent)
              .toList();
          final availableProviders = snapshot.providerData?.items ?? <ProviderInfo>[];

          final streamingText = _streamingBuffer.snapshot();
          _streamingBuffer.clear();

          final assistantAgentModel = switch (latestAssistant) {
            MessageAssistant(:final modelID, :final providerID) => _resolveAgentModel(
              agents: availableAgents,
              providerID: providerID,
              modelID: modelID,
            ),
            MessageError(:final modelID, :final providerID) => _resolveAgentModel(
              agents: availableAgents,
              providerID: providerID,
              modelID: modelID,
            ),
            MessageUser() || null => null,
          };

          final refreshedChildSessions = [...snapshot.childSessions];
          _sortChildrenByUpdatedDesc(refreshedChildSessions);

          final latest = state;
          if (latest is! SessionDetailLoaded) return;
          final preservedSelectedAgent = latest.selectedAgent;
          final preservedSelectedAgentModel = latest.selectedAgentModel;
          final preservedStagedCommand = latest.stagedCommand;
          final availableVariants = _deriveAvailableVariants(
            providers: availableProviders,
            model: preservedSelectedAgentModel,
          );

          final refreshedSessionStatus = snapshot.statuses[_sessionId] ?? const SessionStatus.idle();
          final retryMessage = switch (refreshedSessionStatus) {
            SessionStatusRetry(:final message) => message,
            SessionStatusIdle() => null,
            SessionStatusBusy() => null,
          };

          emit(
            latest.copyWith(
              messages: snapshot.messages,
              streamingText: streamingText,
              sessionStatus: refreshedSessionStatus,
              retryErrorMessage: retryMessage,
              pendingQuestions: _mapPendingQuestions(snapshot.pendingQuestions),
              pendingPermissions: _mapPendingPermissions(snapshot.pendingPermissions),
              agent: latestAssistant?.agent,
              assistantAgentModel: assistantAgentModel,
              children: refreshedChildSessions,
              childStatuses: childStatuses,
              availableAgents: availableAgents,
              availableProviders: availableProviders,
              availableCommands: snapshot.commands,
              sessionTitle: snapshot.canonicalSessionTitle ?? latest.sessionTitle,
              selectedAgent: preservedSelectedAgent,
              selectedAgentModel: preservedSelectedAgentModel,
              stagedCommand: _resolveStagedCommand(
                availableCommands: snapshot.commands,
                stagedCommand: preservedStagedCommand,
              ),
              queuedMessages: _promptQueue.items,
              isRefreshing: false,
              availableVariants: availableVariants,
            ),
          );
          // Re-assert that the user is viewing this session now that the
          // refreshed transcript has rendered. After a resume/reconnect the
          // viewing service intentionally does not auto-re-assert (that would
          // mark the session seen on the bridge before fresh content is shown,
          // clearing its bold while the user still sees the stale snapshot), so
          // the cubit drives it here once the refresh has landed.
          //
          // BUT skip the reassert when a forced fresh refresh is still pending:
          // this refresh may have started before the app was backgrounded, so
          // its snapshot can predate hidden activity. Re-asserting now would mark
          // that activity seen before it's loaded. The queued post-resume forced
          // refresh will re-assert once it renders genuinely-fresh content.
          if (!_pendingForcedRefresh) {
            _sessionViewingService.setViewingSession(_sessionId);
          }
          _drainPendingEvents();
        case SessionDetailLoadResultWaitingForConnection():
          _waitingForConnection = true;
          final latest = state;
          if (latest is SessionDetailLoaded) {
            emit(latest.copyWith(isRefreshing: false, queuedMessages: _promptQueue.items));
          }
        case SessionDetailLoadResultFailed(:final error):
          logw("Silent refresh failed: ${error.toString()}");
          final latest = state;
          if (latest is SessionDetailLoaded) {
            emit(latest.copyWith(isRefreshing: false, queuedMessages: _promptQueue.items));
          }
      }
    } catch (error) {
      logw("Silent refresh failed: ${error.toString()}");
      if (isClosed) return;
      final latest = state;
      if (latest is SessionDetailLoaded) {
        emit(latest.copyWith(isRefreshing: false, queuedMessages: _promptQueue.items));
      }
    }
  }

  CommandInfo? _resolveStagedCommand({
    required List<CommandInfo> availableCommands,
    required CommandInfo? stagedCommand,
  }) {
    if (stagedCommand == null) return null;
    return availableCommands.firstWhereOrNull((c) => c.name == stagedCommand.name);
  }

  /// Returns the latest assistant [Message] from the list, or null if none.
  Message? _latestAssistantMessage(List<MessageWithParts> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final info = messages[i].info;
      if (info is MessageAssistant) return info;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // SSE event processing
  // ---------------------------------------------------------------------------

  void _handleEvent(SesoriSessionEvent event) {
    if (state is SessionDetailLoading) {
      _pendingSessionEvents.add(event);
      return;
    }
    _processSessionEvent(event);
  }

  void _processSessionEvent(SesoriSessionEvent event) {
    try {
      switch (event) {
        case SesoriMessageUpdated(:final info):
          _onMessageUpdated(info);
        case SesoriMessageRemoved(:final messageID):
          _onMessageRemoved(messageID);
        case SesoriMessagePartDelta(:final partID, :final delta):
          _onPartDelta(partId: partID, delta: delta);
        case SesoriMessagePartUpdated(:final part):
          _onPartUpdated(part);
        case SesoriMessagePartRemoved(:final messageID, :final partID):
          _onPartRemoved(messageId: messageID, partId: partID);
        case SesoriSessionStatus(:final status):
          _onSessionStatus(status: status);
        case SesoriQuestionAsked():
          _onQuestionAsked(event);
        case SesoriQuestionReplied(:final requestID):
          _onQuestionResolved(requestID);
        case SesoriQuestionRejected(:final requestID):
          _onQuestionResolved(requestID);
        case SesoriPermissionAsked():
          _onPermissionAsked(event);
        case SesoriPermissionReplied(:final requestID):
          _onPermissionResolved(requestID);
        case SesoriSessionUpdated(:final info):
          _onSessionUpdated(info);
        case SesoriCommandExecuted():
          _onDataMayBeStale();
        case SesoriSessionPromptDefaultsChanged(:final promptDefaults):
          _onPromptDefaultsChanged(promptDefaults);
        case SesoriSessionCreated() ||
            SesoriSessionDeleted() ||
            SesoriSessionDiff() ||
            SesoriSessionError() ||
            SesoriSessionCompacted() ||
            SesoriTodoUpdated():
          break;
      }
    } catch (e, st) {
      loge("SSE event handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_detail_event:${event.runtimeType.toString()}",
              fatal: false,
              reason: "Failed to handle session event",
              information: [event.runtimeType.toString()],
            )
            .catchError((_) {}),
      );
    }
  }

  void _handleGlobalEvent(SseEvent event) {
    if (state is SessionDetailLoading) {
      if (_isRelevantGlobalEvent(event)) {
        _pendingGlobalEvents.add(event);
      }
      return;
    }
    _processGlobalEvent(event);
  }

  /// Returns whether a global SSE event could affect this session's state.
  /// Used to avoid buffering high-volume irrelevant events (PTY, file watcher,
  /// LSP, etc.) from the global stream while the cubit is loading.
  ///
  /// Conservative: if we can't tell at buffer time whether an event is
  /// relevant (e.g. [SesoriSessionStatus] or [SesoriSessionUpdated] may be
  /// for one of our child sessions), we queue it and let the replay handler
  /// decide.
  ///
  /// [SesoriSessionsUpdated] is intentionally excluded: it triggers a silent
  /// refresh, but during loading we are already fetching the latest snapshot,
  /// so replaying it would cause a redundant refresh immediately after load.
  bool _isRelevantGlobalEvent(SseEvent event) {
    return switch (event.data) {
      // Child session created for this session — definitely relevant.
      SesoriSessionCreated(:final info) => info.parentID == _sessionId,
      // May be a status update for one of our children. We don't know our
      // children during loading, so queue conservatively and let replay handler
      // filter by checking current.children.
      SesoriSessionStatus() => true,
      // Only queue updates for our direct children (info.parentID tells us
      // this at buffer time). Updates for unrelated sessions are dropped
      // immediately to avoid accumulating irrelevant backlog.
      SesoriSessionUpdated(:final info) => info.parentID == _sessionId,
      // Permission/question events for a descendant (sub-agent) session that
      // surfaces on this session must be buffered so they replay after load.
      SesoriPermissionAsked(:final sessionID, :final displaySessionId) =>
        _surfacesChildRequestHere(sessionID: sessionID, displaySessionId: displaySessionId),
      SesoriPermissionReplied(:final sessionID, :final displaySessionId) =>
        _surfacesChildRequestHere(sessionID: sessionID, displaySessionId: displaySessionId),
      SesoriQuestionAsked(:final sessionID, :final displaySessionId) =>
        _surfacesChildRequestHere(sessionID: sessionID, displaySessionId: displaySessionId),
      SesoriQuestionReplied(:final sessionID, :final displaySessionId) =>
        _surfacesChildRequestHere(sessionID: sessionID, displaySessionId: displaySessionId),
      SesoriQuestionRejected(:final sessionID, :final displaySessionId) =>
        _surfacesChildRequestHere(sessionID: sessionID, displaySessionId: displaySessionId),
      // Definitively irrelevant high-volume events.
      SesoriServerConnected() ||
      SesoriServerHeartbeat() ||
      SesoriServerInstanceDisposed() ||
      SesoriGlobalDisposed() ||
      SesoriSessionDeleted() ||
      SesoriSessionDiff() ||
      SesoriSessionError() ||
      SesoriSessionCompacted() ||
      SesoriCommandExecuted() ||
      SesoriMessageUpdated() ||
      SesoriMessageRemoved() ||
      SesoriMessagePartUpdated() ||
      SesoriMessagePartDelta() ||
      SesoriMessagePartRemoved() ||
      SesoriPtyCreated() ||
      SesoriPtyUpdated() ||
      SesoriPtyExited() ||
      SesoriPtyDeleted() ||
      SesoriPermissionUpdated() ||
      SesoriTodoUpdated() ||
      SesoriProjectsSummary() ||
      SesoriProjectUpdated() ||
      SesoriVcsBranchUpdated() ||
      SesoriFileEdited() ||
      SesoriFileWatcherUpdated() ||
      SesoriLspUpdated() ||
      SesoriLspClientDiagnostics() ||
      SesoriMcpToolsChanged() ||
      SesoriMcpBrowserOpenFailed() ||
      SesoriInstallationUpdated() ||
      SesoriInstallationUpdateAvailable() ||
      SesoriWorkspaceReady() ||
      SesoriWorkspaceFailed() ||
      SesoriTuiToastShow() ||
      SesoriWorktreeReady() ||
      SesoriWorktreeFailed() ||
      SesoriSessionPromptDefaultsChanged() ||
      // Unseen-state changes are list-level concerns handled by the trackers;
      // the detail screen does not react to them.
      SesoriSessionUnseenChanged() ||
      // Intentionally excluded: triggers a silent refresh, but during loading
      // we are already fetching the latest snapshot, so replaying it would
      // cause a redundant refresh immediately after load.
      SesoriSessionsUpdated() => false,
    };
  }

  void _processGlobalEvent(SseEvent event) {
    final data = event.data;
    try {
      switch (data) {
        case SesoriSessionCreated(:final info) when info.parentID == _sessionId:
          _onChildSessionCreated(info);
        case SesoriSessionStatus(:final sessionID, :final status):
          _onChildSessionStatus(sessionId: sessionID, status: status);
        case SesoriSessionUpdated(:final info):
          _onChildSessionUpdated(info);
        // A child (sub-agent) session's permission/question, surfaced on this
        // parent session via the bridge-resolved display session so it can be
        // answered here without drilling into the child. Own-session events go
        // through _processSessionEvent; the guard matches only descendants.
        case final SesoriPermissionAsked event
            when _surfacesChildRequestHere(sessionID: event.sessionID, displaySessionId: event.displaySessionId):
          _onPermissionAsked(event);
        case final SesoriPermissionReplied event
            when _surfacesChildRequestHere(sessionID: event.sessionID, displaySessionId: event.displaySessionId):
          _onPermissionResolved(event.requestID);
        case final SesoriQuestionAsked event
            when _surfacesChildRequestHere(sessionID: event.sessionID, displaySessionId: event.displaySessionId):
          _onQuestionAsked(event);
        case final SesoriQuestionReplied event
            when _surfacesChildRequestHere(sessionID: event.sessionID, displaySessionId: event.displaySessionId):
          _onQuestionResolved(event.requestID);
        case final SesoriQuestionRejected event
            when _surfacesChildRequestHere(sessionID: event.sessionID, displaySessionId: event.displaySessionId):
          _onQuestionResolved(event.requestID);
        case SesoriSessionCreated() ||
            SesoriSessionDeleted() ||
            SesoriSessionDiff() ||
            SesoriSessionError() ||
            SesoriSessionCompacted() ||
            SesoriServerConnected() ||
            SesoriServerHeartbeat() ||
            SesoriServerInstanceDisposed() ||
            SesoriGlobalDisposed() ||
            SesoriMessageUpdated() ||
            SesoriMessageRemoved() ||
            SesoriMessagePartUpdated() ||
            SesoriMessagePartDelta() ||
            SesoriMessagePartRemoved() ||
            SesoriPtyCreated() ||
            SesoriPtyUpdated() ||
            SesoriPtyExited() ||
            SesoriPtyDeleted() ||
            SesoriPermissionAsked() ||
            SesoriPermissionReplied() ||
            SesoriPermissionUpdated() ||
            SesoriQuestionAsked() ||
            SesoriQuestionReplied() ||
            SesoriQuestionRejected() ||
            SesoriCommandExecuted() ||
            SesoriTodoUpdated() ||
            SesoriProjectsSummary() ||
            SesoriProjectUpdated() ||
            SesoriVcsBranchUpdated() ||
            SesoriFileEdited() ||
            SesoriFileWatcherUpdated() ||
            SesoriLspUpdated() ||
            SesoriLspClientDiagnostics() ||
            SesoriMcpToolsChanged() ||
            SesoriMcpBrowserOpenFailed() ||
            SesoriInstallationUpdated() ||
            SesoriInstallationUpdateAvailable() ||
            SesoriWorkspaceReady() ||
            SesoriWorkspaceFailed() ||
            SesoriTuiToastShow() ||
            SesoriWorktreeReady() ||
            SesoriWorktreeFailed() ||
            SesoriSessionUnseenChanged() ||
            SesoriSessionPromptDefaultsChanged():
          break;
        case SesoriSessionsUpdated(:final projectID):
          if (projectID.isNotEmpty && projectID == _projectId) {
            _silentRefresh();
          }
      }
    } catch (e, st) {
      loge("SSE global event handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_detail_global_event:${data.runtimeType.toString()}",
              fatal: false,
              reason: "Failed to handle global session event",
              information: [data.runtimeType.toString()],
            )
            .catchError((_) {}),
      );
    }
  }

  /// Replays any SSE events that were buffered while the cubit was not in
  /// [SessionDetailLoaded] state. Called after a successful load/refresh.
  void _drainPendingEvents() {
    if (state is! SessionDetailLoaded) return;
    final sessionEvents = List<SesoriSessionEvent>.of(_pendingSessionEvents);
    _pendingSessionEvents.clear();
    sessionEvents.forEach(_processSessionEvent);
    final globalEvents = List<SseEvent>.of(_pendingGlobalEvents);
    _pendingGlobalEvents.clear();
    globalEvents.forEach(_processGlobalEvent);
  }

  void _onSessionUpdated(Session session) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    if (isClosed) return;
    emit(current.copyWith(sessionTitle: session.title));
  }

  void _onPromptDefaultsChanged(SessionPromptDefaults promptDefaults) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final agents = current.availableAgents;
    final providers = current.availableProviders;
    final persistedAgent = promptDefaults.agent;
    final persistedModel = promptDefaults.model;

    final bool hasValidPersistedAgent = persistedAgent != null && agents.any((a) => a.name == persistedAgent);
    final bool hasValidPersistedModel =
        persistedModel != null &&
        providers.any((p) => p.id == persistedModel.providerID && p.models.containsKey(persistedModel.modelID));

    final newAgent = hasValidPersistedAgent ? persistedAgent : current.selectedAgent;
    final newModel = hasValidPersistedModel ? persistedModel : current.selectedAgentModel;

    if (isClosed) return;
    emit(
      current.copyWith(
        selectedAgent: newAgent,
        selectedAgentModel: newModel,
      ),
    );
  }

  void _onChildSessionCreated(Session child) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    // Avoid duplicates.
    if (current.children.any((c) => c.id == child.id)) return;

    if (isClosed) return;
    final updated = [...current.children, child];
    _sortChildrenByUpdatedDesc(updated);
    emit(current.copyWith(children: updated));
  }

  void _onChildSessionStatus({required String sessionId, required SessionStatus status}) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    // Update if this is one of our child sessions.
    if (!current.children.any((c) => c.id == sessionId)) return;

    if (isClosed) return;
    emit(
      current.copyWith(
        childStatuses: {...current.childStatuses, sessionId: status},
      ),
    );
  }

  void _onChildSessionUpdated(Session updatedChild) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    // Only update if this is one of our child sessions.
    final index = current.children.indexWhere((c) => c.id == updatedChild.id);
    if (index < 0) return;

    if (isClosed) return;
    final updatedChildren = List<Session>.of(current.children)..[index] = updatedChild;
    _sortChildrenByUpdatedDesc(updatedChildren);
    emit(current.copyWith(children: updatedChildren));
  }

  /// Whether a child (sub-agent) permission/question event should surface on
  /// this (parent) session. Own-session events arrive via the session-scoped
  /// stream and are handled in [_processSessionEvent]; this gates the global
  /// stream to descendant requests whose display (root) session is this session.
  /// Falls back to [sessionID] when the bridge did not provide a display session
  /// (older bridge), which collapses to today's own-session-only behaviour.
  bool _surfacesChildRequestHere({required String sessionID, required String? displaySessionId}) {
    return sessionID != _sessionId && (displaySessionId ?? sessionID) == _sessionId;
  }

  void _onMessageUpdated(Message message) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final messages = List<MessageWithParts>.from(current.messages);
    final index = messages.indexWhere((item) => item.info.id == message.id);

    if (index >= 0) {
      messages[index] = messages[index].copyWith(info: message);
    } else {
      messages.add(MessageWithParts(info: message, parts: const []));
    }

    if (isClosed) return;

    if (message is MessageAssistant) {
      final assistantAgentModel = message.providerID != null && message.modelID != null
          ? _resolveAgentModel(
              agents: current.availableAgents,
              providerID: message.providerID,
              modelID: message.modelID,
            )
          : current.assistantAgentModel;
      emit(
        current.copyWith(
          messages: messages,
          agent: message.agent ?? current.agent,
          assistantAgentModel: assistantAgentModel,
        ),
      );
    } else {
      emit(current.copyWith(messages: messages));
    }
  }

  void _onMessageRemoved(String messageId) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final messages = current.messages.where((item) => item.info.id != messageId).toList();

    if (isClosed) return;
    emit(current.copyWith(messages: messages));
  }

  void _onSessionStatus({required SessionStatus status}) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    if (isClosed) return;
    final retryMessage = switch (status) {
      SessionStatusRetry(:final message) => message,
      SessionStatusIdle() => null,
      SessionStatusBusy() => null,
    };
    emit(current.copyWith(sessionStatus: status, retryErrorMessage: retryMessage));
  }

  // ---------------------------------------------------------------------------
  // Streaming text
  // ---------------------------------------------------------------------------

  void _onPartDelta({required String partId, required String delta}) {
    _streamingBuffer.appendDelta(partId: partId, delta: delta);
  }

  void _onPartUpdated(MessagePart part) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    _streamingBuffer.removePart(part.id);

    final messages = List<MessageWithParts>.from(current.messages);
    final messageIndex = messages.indexWhere((item) => item.info.id == part.messageID);

    if (messageIndex >= 0) {
      final message = messages[messageIndex];
      final parts = List<MessagePart>.from(message.parts);
      final partIndex = parts.indexWhere((item) => item.id == part.id);

      if (partIndex >= 0) {
        parts[partIndex] = part;
      } else {
        parts.add(part);
      }

      messages[messageIndex] = message.copyWith(parts: parts);
    }

    if (isClosed) return;
    emit(
      current.copyWith(
        messages: messages,
        streamingText: _streamingBuffer.snapshot(),
      ),
    );
  }

  void _onPartRemoved({required String messageId, required String partId}) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    _streamingBuffer.removePart(partId);

    final messages = List<MessageWithParts>.from(current.messages);
    final messageIndex = messages.indexWhere((item) => item.info.id == messageId);

    if (messageIndex >= 0) {
      final message = messages[messageIndex];
      final parts = message.parts.where((item) => item.id != partId).toList();
      messages[messageIndex] = message.copyWith(parts: parts);
    }

    if (isClosed) return;
    emit(
      current.copyWith(
        messages: messages,
        streamingText: _streamingBuffer.snapshot(),
      ),
    );
  }

  void _emitStreamingSnapshot() {
    if (isClosed) return;
    final current = state;
    if (current is! SessionDetailLoaded) return;
    emit(current.copyWith(streamingText: _streamingBuffer.snapshot()));
  }

  // ---------------------------------------------------------------------------
  // Message queue
  // ---------------------------------------------------------------------------

  bool get _isConnected => _connectionService.currentStatus is ConnectionConnected;

  void _onDataMayBeStale() {
    if (state is! SessionDetailLoaded) return;
    final status = _connectionService.status.value;
    if (status is ConnectionConnected) {
      _silentRefresh();
    } else {
      _needsStaleRefresh = true;
    }
  }

  void _onLifecycleChanged(LifecycleState state) {
    switch (state) {
      case LifecycleState.paused:
      case LifecycleState.hidden:
        _wasPaused = true;
      case LifecycleState.resumed:
        if (!_wasPaused) return;
        _wasPaused = false;
        // If any load is actually IN FLIGHT, its response may predate hidden
        // activity. Flag EVERY in-flight load so each refreshes before declaring
        // the view instead of acting on a possibly-stale snapshot. Only in-flight
        // loads matter: a failed/waiting state with no load running (e.g. the
        // user will retry after resume) should NOT be deferred, or its fresh load
        // would render loaded-but-not-declared and miss in-view activity until a
        // second forced refresh.
        if (_loadInFlight) {
          _resumedLoadIds.addAll(_activeLoadIds);
          return;
        }
        // Not loaded and not loading (failed/waiting): nothing to re-assert yet;
        // the next load/retry declares the view on completion.
        if (this.state is! SessionDetailLoaded) return;
        // On every resume, refresh so the transcript is current, then the
        // refresh re-asserts the viewing session once fresh content renders.
        // This covers short resumes that don't emit dataMayBeStale: the
        // viewing service cleared the view on background and does not
        // auto-re-assert, so without this the bridge would have no active
        // viewer and later in-view activity would be persisted as unseen.
        // Force a fresh refresh (don't coalesce onto a request that may have
        // started before backgrounding and would miss hidden activity).
        if (_isConnected) {
          _forceFreshRefresh();
        } else {
          // Disconnected: defer to the reconnect path, which refreshes (and
          // thus re-asserts) once the connection returns. Flag that this deferred
          // refresh must be a FORCED-fresh one (resume guarantee), not a
          // coalescing _silentRefresh.
          _needsStaleRefresh = true;
          _needsFreshRefreshOnReconnect = true;
        }
      case LifecycleState.inactive:
      case LifecycleState.detached:
        break;
    }
  }

  void _onConnectionStatusChanged(ConnectionStatus status) {
    if (isClosed) return;
    final isConnected = status is ConnectionConnected;
    final reconnected = isConnected && !_wasConnected;
    _wasConnected = isConnected;
    if (isConnected) {
      if (_waitingForConnection) {
        _waitingForConnection = false;
        unawaited(_loadMessages(isReload: true));
        return;
      }
      _tryDrainQueue();
      if (_needsStaleRefresh) {
        _needsStaleRefresh = false;
        // A refresh deferred from a resume must be forced-fresh to keep the
        // post-resume guarantee; an ordinary stale signal can coalesce.
        if (_needsFreshRefreshOnReconnect) {
          _needsFreshRefreshOnReconnect = false;
          _forceFreshRefresh();
        } else {
          _silentRefresh();
        }
      } else if (reconnected && state is SessionDetailLoaded) {
        // A foreground relay reconnect (no lifecycle resume, no stale signal):
        // the bridge released the old connection's viewer, so re-establish a
        // current transcript and re-declare the view. Forced-fresh so the
        // re-assert only happens after content that reflects the reconnect.
        _forceFreshRefresh();
      }
    }
  }

  /// Attempts to send the next queued message when the condition is met:
  /// connection is alive.
  void _tryDrainQueue() {
    if (isClosed) return;
    final current = state;
    if (current is! SessionDetailLoaded) return;
    unawaited(_drainQueuedMessages());
  }

  Future<void> sendMessage({required String text, required String? command}) async {
    final current = state;
    final trimmed = text.trim();
    final normalizedCommand = command?.normalize();
    if (trimmed.isEmpty && normalizedCommand == null) return;

    final submission = QueuedSessionSubmission(text: trimmed, command: normalizedCommand);
    if (current is! SessionDetailLoaded || !_isConnected || _promptQueue.isNotEmpty || _isSending) {
      _promptQueue.enqueue(submission);
      _emitQueueUpdate(current is SessionDetailLoaded ? current : null);
      if (_isConnected && current is SessionDetailLoaded) {
        unawaited(_drainQueuedMessages());
      }
      return;
    }

    final result = await _sessionRepository.sendMessage(
      sessionId: _sessionId,
      text: trimmed,
      agent: current.selectedAgent,
      model: _agentModelToPromptModel(current.selectedAgentModel),
      variant: switch (current.selectedAgentModel?.variant) {
        null => null,
        final variant => SessionVariant(id: variant),
      },
      command: normalizedCommand,
    );

    if (result case ErrorResponse()) {
      _promptQueue.requeue(submission);
      _emitQueueUpdate(_latestLoadedState());
    }
  }

  void cancelQueuedMessage(int index) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final removed = _promptQueue.cancel(index);
    if (removed != null) {
      _emitQueueUpdate(current);
    }
  }

  /// Syncs queued prompt items into the cubit state.
  void _emitQueueUpdate([SessionDetailLoaded? known]) {
    if (isClosed) return;
    final current = known ?? state;
    if (current is! SessionDetailLoaded) return;
    emit(current.copyWith(queuedMessages: _promptQueue.items));
  }

  Future<void> _drainQueuedMessages() async {
    if (_isSending) return;
    final current = state;
    if (current is! SessionDetailLoaded) return;
    if (!_isConnected) return;

    final submission = _promptQueue.dequeue();
    if (submission == null) return;

    _isSending = true;
    _emitQueueUpdate(current);

    var sendSucceeded = false;
    try {
      final result = await _sessionRepository.sendMessage(
        sessionId: _sessionId,
        text: submission.text,
        agent: current.selectedAgent,
        model: _agentModelToPromptModel(current.selectedAgentModel),
        variant: switch (current.selectedAgentModel?.variant) {
          null => null,
          final variant => SessionVariant(id: variant),
        },
        command: submission.command,
      );

      if (result case ErrorResponse()) {
        _promptQueue.requeue(submission);
        _emitQueueUpdate(_latestLoadedState());
      } else {
        sendSucceeded = true;
      }
    } finally {
      _isSending = false;
    }

    if (sendSucceeded) {
      final latest = state;
      if (latest is SessionDetailLoaded && _isConnected) {
        _emitQueueUpdate(latest);
        unawaited(_drainQueuedMessages());
      }
    }
  }

  SessionDetailLoaded? _latestLoadedState() {
    final current = state;
    return current is SessionDetailLoaded ? current : null;
  }

  PromptModel? _agentModelToPromptModel(AgentModel? agentModel) {
    if (agentModel == null) return null;
    return PromptModel(providerID: agentModel.providerID, modelID: agentModel.modelID);
  }

  AgentModel? _resolveAgentModel({
    required List<AgentInfo> agents,
    required String? providerID,
    required String? modelID,
  }) {
    if (providerID == null || modelID == null) return null;
    final agent = agents.firstWhereOrNull(
      (a) => a.model?.providerID == providerID && a.model?.modelID == modelID,
    );
    return agent?.model ??
        AgentModel(
          providerID: providerID,
          modelID: modelID,
          variant: null,
        );
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Clears all push notifications for this session.
  ///
  /// Call when the session detail screen is entered or when a question/permission
  /// prompt becomes visible — the notification has served its purpose once the
  /// user is already looking at the content.
  void clearNotifications() {
    _notificationCanceller.cancelForSession(sessionId: _sessionId);
  }

  // ---------------------------------------------------------------------------
  // Questions
  // ---------------------------------------------------------------------------

  void _onQuestionAsked(SesoriQuestionAsked question) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final pending = List<SesoriQuestionAsked>.from(current.pendingQuestions);
    // Avoid duplicates (same question arriving twice).
    if (pending.any((q) => q.id == question.id)) return;

    pending.add(question);

    if (isClosed) return;
    emit(current.copyWith(pendingQuestions: pending));
    _questionStream.add(question);
  }

  void _onQuestionResolved(String requestId) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final pending = current.pendingQuestions.where((q) => q.id != requestId).toList();

    if (isClosed) return;
    emit(current.copyWith(pendingQuestions: pending));
  }

  void _onPermissionAsked(SesoriPermissionAsked permission) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final pending = List<SesoriPermissionAsked>.from(current.pendingPermissions);
    if (pending.any((item) => item.requestID == permission.requestID)) return;

    pending.add(permission);

    if (isClosed) return;
    emit(current.copyWith(pendingPermissions: pending));
    _permissionStream.add(permission);
  }

  void _onPermissionResolved(String requestId) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final pending = current.pendingPermissions.where((item) => item.requestID != requestId).toList();

    if (isClosed) return;
    emit(current.copyWith(pendingPermissions: pending));
  }

  Future<bool> replyToQuestion({
    required String requestId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) async {
    // Optimistically remove before the API call so the screen sees the
    // updated state synchronously (prevents auto-chain re-opening the
    // same question).
    _onQuestionResolved(requestId);
    _notificationCanceller.cancelForSession(sessionId: sessionId);
    try {
      final result = await _sessionRepository.replyToQuestion(
        requestId: requestId,
        sessionId: sessionId,
        answers: answers,
      );
      if (result case ErrorResponse(:final error)) {
        throw error;
      }
      return true;
    } on Object catch (e, st) {
      loge("Failed to reply to question $requestId", e, st);
      await _loadMessages(isReload: true);
      return false;
    }
  }

  Future<bool> rejectQuestion(String requestId) async {
    // Reject against the question's owning session (which may be a child/
    // sub-agent surfaced on this root), mirroring the reply path, so the bridge
    // clears its tracker under the correct session instead of the open root.
    final current = state;
    final ownerSessionId = current is SessionDetailLoaded
        ? (current.pendingQuestions.firstWhereOrNull((q) => q.id == requestId)?.sessionID ?? _sessionId)
        : _sessionId;
    _onQuestionResolved(requestId);
    _notificationCanceller.cancelForSession(sessionId: _sessionId);
    try {
      final result = await _sessionRepository.rejectQuestion(requestId: requestId, sessionId: ownerSessionId);
      if (result case ErrorResponse(:final error)) {
        throw error;
      }
      return true;
    } on Object catch (e, st) {
      loge("Failed to reject question $requestId", e, st);
      await _loadMessages(isReload: true);
      return false;
    }
  }

  Future<bool> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) async {
    _onPermissionResolved(requestId);
    _notificationCanceller.cancelForSession(sessionId: sessionId);
    try {
      await _permissionRepository.replyToPermission(
        requestId: requestId,
        sessionId: sessionId,
        reply: reply,
      );
      return true;
    } on Object catch (e, st) {
      loge("Failed to reply to permission $requestId", e, st);
      await _loadMessages(isReload: true);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Settings & control
  // ---------------------------------------------------------------------------

  void selectAgent(String agent) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final agentInfo = current.availableAgents.firstWhereOrNull((a) => a.name == agent);
    final agentModel = agentInfo?.model;

    if (isClosed) return;
    emit(
      current.copyWith(
        selectedAgent: agent,
        selectedAgentModel: agentModel,
        availableVariants: _deriveAvailableVariants(
          providers: current.availableProviders,
          model: agentModel,
        ),
      ),
    );
  }

  void selectModel({required String providerID, required String modelID}) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final previousVariant = current.selectedAgentModel?.variant;
    final newModel = AgentModel(providerID: providerID, modelID: modelID, variant: null);
    final availableVariants = _deriveAvailableVariants(
      providers: current.availableProviders,
      model: newModel,
    );
    final variant = previousVariant != null && availableVariants.any((v) => v.id == previousVariant)
        ? previousVariant
        : null;

    final agentModel = _resolveAgentModel(
      agents: current.availableAgents,
      providerID: providerID,
      modelID: modelID,
    );

    if (isClosed) return;
    emit(
      current.copyWith(
        selectedAgentModel: agentModel?.copyWith(variant: variant),
        availableVariants: availableVariants,
      ),
    );
  }

  void selectVariant(SessionVariant? variant) {
    final current = state;
    if (current is! SessionDetailLoaded) return;
    final agentModel = current.selectedAgentModel;
    if (agentModel == null) return;

    if (isClosed) return;
    emit(current.copyWith(selectedAgentModel: agentModel.copyWith(variant: variant?.id)));
  }

  void stageCommand(CommandInfo command) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    if (isClosed) return;
    emit(current.copyWith(stagedCommand: command));
  }

  void clearStagedCommand() {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    if (isClosed) return;
    emit(current.copyWith(stagedCommand: null));
  }

  Future<void> abort() async {
    try {
      final current = state;
      final futures = <Future<ApiResponse<void>>>[_sessionRepository.abortSession(sessionId: _sessionId)];

      // Also abort any active child sessions (busy or retrying).
      if (current is SessionDetailLoaded) {
        for (final entry in current.childStatuses.entries) {
          final status = entry.value;
          if (status is SessionStatusBusy || status is SessionStatusRetry) {
            futures.add(_sessionRepository.abortSession(sessionId: entry.key));
          }
        }
      }

      final results = await Future.wait(futures);
      for (final result in results) {
        if (result case ErrorResponse(:final error)) {
          throw error;
        }
      }
    } on Object catch (e, st) {
      loge("Failed to abort session(s)", e, st);
    }
  }

  SessionDetailLoaded _buildLoadedState({required SessionDetailSnapshot snapshot}) {
    final latestAssistant = _latestAssistantMessage(snapshot.messages);
    final childSessions = [...snapshot.childSessions];
    _sortChildrenByUpdatedDesc(childSessions);
    final childIds = childSessions.map((c) => c.id).toSet();
    final childStatuses = Map<String, SessionStatus>.fromEntries(
      snapshot.statuses.entries.where((e) => childIds.contains(e.key)),
    );
    final agents = snapshot.agents
        .whereType<AgentInfo>()
        .where((a) => !a.hidden && a.mode != AgentMode.subagent)
        .toList();
    final providers = snapshot.providerData?.items ?? <ProviderInfo>[];

    final persistedDefaults = snapshot.promptDefaults;
    final persistedAgent = persistedDefaults?.agent;
    final persistedModel = persistedDefaults?.model;

    final bool hasValidPersistedAgent = persistedAgent != null && agents.any((a) => a.name == persistedAgent);
    final bool hasValidPersistedModel =
        persistedModel != null &&
        providers.any((p) => p.id == persistedModel.providerID && p.models.containsKey(persistedModel.modelID));

    final String defaultAgent = hasValidPersistedAgent
        ? persistedAgent
        : (agents.isNotEmpty ? agents.first.name : "build");

    final AgentModel? defaultAgentModel;
    if (hasValidPersistedModel) {
      defaultAgentModel = persistedModel;
    } else if (agents.isNotEmpty && agents.first.model != null) {
      defaultAgentModel = agents.first.model;
    } else if (providers.isNotEmpty) {
      // Walk the provider list and use the first one that has at least
      // one available model. Previously we only looked at `providers.first`,
      // which silently produced `null` when the first provider happened
      // to be misconfigured or fully deprecated.
      AgentModel? pickedModel;
      for (final provider in providers) {
        final picked = _defaultModelSelector.pickFromProvider(
          models: provider.models,
        );
        if (picked != null) {
          pickedModel = AgentModel(
            providerID: provider.id,
            modelID: picked.id,
            variant: null,
          );
          break;
        }
      }
      defaultAgentModel = pickedModel;
    } else {
      defaultAgentModel = null;
    }

    final assistantAgentModel = switch (latestAssistant) {
      MessageAssistant(:final modelID, :final providerID) => _resolveAgentModel(
        agents: agents,
        providerID: providerID,
        modelID: modelID,
      ),
      MessageError(:final modelID, :final providerID) => _resolveAgentModel(
        agents: agents,
        providerID: providerID,
        modelID: modelID,
      ),
      MessageUser() || null => null,
    };

    final availableVariants = _deriveAvailableVariants(
      providers: providers,
      model: defaultAgentModel,
    );

    final initialSessionStatus = snapshot.statuses[_sessionId] ?? const SessionStatus.idle();
    final initialRetryMessage = switch (initialSessionStatus) {
      SessionStatusRetry(:final message) => message,
      SessionStatusIdle() => null,
      SessionStatusBusy() => null,
    };

    return SessionDetailLoaded(
      messages: snapshot.messages,
      streamingText: const {},
      sessionStatus: initialSessionStatus,
      retryErrorMessage: initialRetryMessage,
      pendingQuestions: _mapPendingQuestions(snapshot.pendingQuestions),
      pendingPermissions: _mapPendingPermissions(snapshot.pendingPermissions),
      sessionTitle: snapshot.canonicalSessionTitle,
      agent: latestAssistant?.agent,
      assistantAgentModel: assistantAgentModel,
      children: childSessions,
      childStatuses: childStatuses,
      isRootSession: snapshot.isRootSession,
      queuedMessages: _promptQueue.items,
      availableAgents: agents,
      availableProviders: providers,
      availableCommands: snapshot.commands,
      selectedAgent: defaultAgent,
      selectedAgentModel: defaultAgentModel,
      stagedCommand: null,
      isRefreshing: false,
      availableVariants: availableVariants,
    );
  }

  List<SessionVariant> _deriveAvailableVariants({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    final providerID = model?.providerID;
    final modelID = model?.modelID;
    final provider = providerID != null ? providers.firstWhereOrNull((p) => p.id == providerID) : null;
    final m = provider?.models[modelID];
    return m?.variants.where((v) => v != "none").map((v) => SessionVariant(id: v)).toList() ?? [];
  }

  List<SesoriQuestionAsked> _mapPendingQuestions(List<PendingQuestion> pendingQuestions) {
    // The bridge already returns the questions to surface on this session (its
    // own plus any descendant/sub-agent session whose root is this session), so
    // map all of them through.
    return pendingQuestions
        .map(
          (q) => SesoriQuestionAsked(
            id: q.id,
            sessionID: q.sessionID,
            displaySessionId: q.displaySessionId,
            questions: q.questions,
          ),
        )
        .toList();
  }

  List<SesoriPermissionAsked> _mapPendingPermissions(List<PendingPermission> pendingPermissions) {
    // The bridge already returns the permissions to surface on this session (its
    // own plus any descendant/sub-agent session whose root is this session), so
    // map all of them through.
    return pendingPermissions
        .map(
          (p) => SesoriPermissionAsked(
            requestID: p.id,
            sessionID: p.sessionID,
            displaySessionId: p.displaySessionId,
            tool: p.tool,
            description: p.description,
          ),
        )
        .toList();
  }

  static void _sortChildrenByUpdatedDesc(List<Session> children) {
    children.sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() {
    _sessionViewingService.clearViewingSession(_sessionId);
    _pendingSessionEvents.clear();
    _pendingGlobalEvents.clear();
    _eventSubscription.cancel();
    _globalEventSubscription.cancel();
    _connectionStatusSubscription.cancel();
    _staleSubscription.cancel();
    _lifecycleSubscription.cancel();
    _streamingBuffer.dispose();
    _questionStream.close();
    _permissionStream.close();
    return super.close();
  }
}

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

  /// Cooldown between silent refreshes triggered by staleness events.
  /// Overridable so tests can exercise the coalescing without real waits.
  final Duration eventRefreshMinInterval;

  late final StreamSubscription<SesoriSessionEvent> _eventSubscription;
  late final StreamSubscription<SseEvent> _globalEventSubscription;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late final StreamSubscription<void> _staleSubscription;
  late final StreamSubscription<LifecycleState> _lifecycleSubscription;
  late final StreamingTextBuffer _streamingBuffer;
  Future<void>? _activeRefresh;
  Timer? _eventRefreshCooldown;
  bool _eventRefreshQueued = false;
  bool _needsStaleRefresh = false;
  bool _waitingForConnection = false;
  bool _wasPaused = false;
  bool _wasConnected = false;

  /// Set when a resume/reconnect requires the next successful silent refresh
  /// to re-declare "the user is viewing this session". The viewing service
  /// clears the declaration on background (and the bridge drops it on
  /// disconnect), and deliberately never re-asserts on its own: declaring a
  /// view marks the session seen globally, so it should follow content the
  /// user can actually see. Re-asserting after the refresh keeps that honest;
  /// any interleaving gap is covered by the live SSE events the open screen
  /// applies anyway.
  bool _reassertViewAfterRefresh = false;

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
    this.eventRefreshMinInterval = const Duration(seconds: 5),
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
    final result = isReload
        ? await _loadService.reload(sessionId: _sessionId, projectId: _projectId)
        : await _loadService.load(sessionId: _sessionId, projectId: _projectId);
    if (isClosed) return;

    switch (result) {
      case SessionDetailLoadResultLoaded(:final snapshot):
        _waitingForConnection = false;
        emit(_buildLoadedState(snapshot: snapshot));
        // Declare the view only now that the transcript has actually loaded —
        // a load that fails or waits for connection must not mark the session
        // read (clearing its bold globally) while the user only saw a
        // loading/error state.
        _sessionViewingService.setViewingSession(_sessionId);
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
    final active = _activeRefresh;
    if (active != null) {
      // This call raced an in-flight refresh. If a staleness signal is
      // queued with no cooldown armed to drain it (the pause path cancels
      // the timer), chain the trailing refresh onto the in-flight completion
      // so the signal is never stranded.
      if (_eventRefreshQueued && _eventRefreshCooldown == null) {
        _drainQueueWhenRefreshCompletes(active);
      }
      return;
    }
    // Any refresh that starts now will fetch a snapshot covering every
    // staleness signal seen so far, so it consumes the queued flag. Signals
    // that arrive while this refresh is in flight re-queue behind it.
    _eventRefreshQueued = false;
    _activeRefresh = _doSilentRefresh().whenComplete(() => _activeRefresh = null);
  }

  void _drainQueueWhenRefreshCompletes(Future<void> activeRefresh) {
    unawaited(
      activeRefresh.whenComplete(() {
        // A newer signal may have armed its own cooldown in the meantime;
        // that timer owns the queue.
        if (isClosed || _eventRefreshCooldown != null) return;
        _onEventRefreshCooldownElapsed();
      }),
    );
  }

  /// Coalesces event-driven staleness signals (sessions.updated,
  /// command.executed, dataMayBeStale) into at most one silent refresh per
  /// [eventRefreshMinInterval]. While the agent works, the bridge can emit
  /// these in sustained bursts (e.g. sessions.updated on every PR-sync tick),
  /// and each silent refresh refetches the whole session snapshot — ~10
  /// encrypted relay round-trips — so refreshing per event keeps the radio
  /// and main isolate busy for the entire turn. The first signal after a
  /// quiet period still refreshes immediately; follow-ups within the cooldown
  /// collapse into a single trailing refresh. Reconnect and app-resume
  /// refreshes bypass this on purpose: they must run promptly and re-assert
  /// the bridge-side view declaration.
  void _requestEventDrivenRefresh() {
    if (state is! SessionDetailLoaded) return;
    if (_wasPaused) {
      // Don't spend the radio while backgrounded: hold the signal and let
      // the resume path's bypass refresh consume it.
      _eventRefreshQueued = true;
      return;
    }
    if (_eventRefreshCooldown != null) {
      _eventRefreshQueued = true;
      return;
    }
    if (_activeRefresh != null) {
      // A refresh is already in flight (e.g. the reconnect path): its
      // snapshot may predate this signal, so queue a trailing refresh behind
      // a cooldown window instead of letting _silentRefresh coalesce the
      // signal into the stale in-flight run.
      _eventRefreshQueued = true;
      _eventRefreshCooldown = Timer(eventRefreshMinInterval, _onEventRefreshCooldownElapsed);
      return;
    }
    _silentRefresh();
    _eventRefreshCooldown = Timer(eventRefreshMinInterval, _onEventRefreshCooldownElapsed);
  }

  void _onEventRefreshCooldownElapsed() {
    _eventRefreshCooldown = null;
    if (!_eventRefreshQueued) return;
    if (isClosed || state is! SessionDetailLoaded) {
      _eventRefreshQueued = false;
      return;
    }
    // While backgrounded the queue is held for the resume bypass refresh.
    if (_wasPaused) return;
    final active = _activeRefresh;
    if (active != null) {
      // The minimum interval has already elapsed, so run the queued refresh
      // as soon as the in-flight one completes instead of waiting another
      // full window.
      _drainQueueWhenRefreshCompletes(active);
      return;
    }
    _silentRefresh();
    _eventRefreshCooldown = Timer(eventRefreshMinInterval, _onEventRefreshCooldownElapsed);
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
          if (_reassertViewAfterRefresh) {
            // A resume/reconnect requested this refresh; the refreshed
            // transcript has rendered, so it is safe to re-declare the view
            // (which marks the session seen on the bridge).
            _reassertViewAfterRefresh = false;
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
      // Unseen-state changes are list-level concerns handled by the tracker;
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
            _requestEventDrivenRefresh();
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
  // COMPATIBILITY 2026-06-20 (v1.1.1): Old bridges omit displaySessionId. Remove the sessionID fallback once those bridges are unsupported.
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
      _requestEventDrivenRefresh();
    } else {
      _needsStaleRefresh = true;
    }
  }

  void _onLifecycleChanged(LifecycleState lifecycleState) {
    switch (lifecycleState) {
      case LifecycleState.paused:
      case LifecycleState.hidden:
        _wasPaused = true;
        // Don't let a queued trailing refresh spend radio/CPU while hidden;
        // the queue is preserved and consumed by the resume bypass refresh.
        _eventRefreshCooldown?.cancel();
        _eventRefreshCooldown = null;
      case LifecycleState.resumed:
        if (!_wasPaused) return;
        _wasPaused = false;
        if (state is! SessionDetailLoaded) return;
        // The viewing service cleared the view on background and does not
        // re-assert on its own; refresh so the transcript reflects activity
        // that arrived while hidden, then re-declare the view once the refresh
        // renders. When disconnected, defer to the reconnect path below.
        _reassertViewAfterRefresh = true;
        if (_isConnected) {
          _silentRefresh();
        } else {
          _needsStaleRefresh = true;
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
        // The disconnect that queued this refresh also released this
        // connection's view on the bridge, so re-assert it once the refresh
        // renders — same as the plain reconnect branch below.
        if (state is SessionDetailLoaded) _reassertViewAfterRefresh = true;
        _silentRefresh();
      } else if (reconnected && state is SessionDetailLoaded) {
        // A foreground relay reconnect: the bridge released the old
        // connection's view declaration, so refresh and re-assert it.
        _reassertViewAfterRefresh = true;
        _silentRefresh();
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
    _eventRefreshCooldown?.cancel();
    _streamingBuffer.dispose();
    _questionStream.close();
    _permissionStream.close();
    return super.close();
  }
}

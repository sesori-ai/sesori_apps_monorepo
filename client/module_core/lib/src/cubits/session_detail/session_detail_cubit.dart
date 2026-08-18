import "dart:async";
import "dart:math";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../foundation/models/composer/composer_attachment.dart";
import "../../foundation/models/composer/composer_draft.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../platform/lifecycle_source.dart";
import "../../platform/notification_canceller.dart";
import "../../repositories/composer_draft_repository.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../repositories/permission_repository.dart";
import "../../repositories/session_repository.dart";
import "../../services/product_analytics_service.dart";
import "../../services/project_viewing_service.dart";
import "../../services/session_detail_load_service.dart";
import "../../services/session_viewing_service.dart";
import "../../utils/model_filter/default_model_selector.dart";
import "deferred_part_event_buffer.dart";
import "prompt_send_queue.dart";
import "queued_session_submission.dart";
import "session_detail_state.dart";
import "streaming_text_buffer.dart";

enum _SessionRefreshTrigger(final String logValue) {
  commandExecuted("command_executed"),
  connectionReconnected("connection_reconnected"),
  lifecycleResumed("lifecycle_resumed"),
  dataMayBeStale("data_may_be_stale"),
  waitingForConnection("waiting_for_connection"),
  queuedEvent("queued_event");

}

enum _SessionRefreshAction() { observed, ignored, queued, coalesced, started, completed }

enum _SessionRefreshResult() { applied, failed, waitingForConnection, staleConnection, closed }

class SessionDetailCubit(
    final ConnectionService _connectionService, {
    required final SessionDetailLoadService _loadService,
    required SessionRepository promptDispatcher,
    required final PermissionRepository _permissionRepository,
    required final SessionViewingService _sessionViewingService,
    required final ProjectViewingService _projectViewingService,
    required final LifecycleSource _lifecycleSource,
    required final ComposerDraftRepository _composerDraftRepository,
    required final ProductAnalyticsService _productAnalyticsService,
    required final String _sessionId,
    required final String _projectId,
    required final NotificationCanceller _notificationCanceller,
    required final FailureReporter _failureReporter,
    /// Cooldown between silent refreshes triggered by staleness events.
  /// Overridable so tests can exercise the coalescing without real waits.
  final Duration eventRefreshMinInterval = const Duration(seconds: 5),
  }) extends Cubit<SessionDetailState> {
  /// Bumped whenever the transcript is replaced wholesale (a refresh or
  /// reload), so an older-page request that started before it can tell its
  /// result no longer joins onto what is shown.
  int _transcriptGeneration = 0;
  final SessionRepository _sessionRepository = promptDispatcher;
  final ProjectViewClaim _projectViewClaim = _projectViewingService.beginDetailClaim(projectId: _projectId);
  static const _defaultModelSelector = DefaultModelSelector();
  ComposerDraft _composerDraft = _composerDraftRepository.readForSession(sessionId: _sessionId);
  final PromptSendQueue _promptQueue = PromptSendQueue();
  final DeferredPartEventBuffer _deferredPartEvents = DeferredPartEventBuffer();

  late final StreamSubscription<SesoriSessionEvent> _eventSubscription;
  late final StreamSubscription<SseEvent> _globalEventSubscription;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late final StreamSubscription<void> _staleSubscription;
  late final StreamSubscription<LifecycleState> _lifecycleSubscription;
  late final StreamingTextBuffer _streamingBuffer;
  Future<void>? _activeRefresh;
  int _commandCatalogGeneration = 0;
  Timer? _eventRefreshCooldown;
  bool _eventRefreshQueued = false;
  bool _needsStaleRefresh = false;
  bool _waitingForConnection = false;
  bool _wasPaused = false;
  bool _wasConnected = false;

  // A disconnect invalidates capability snapshots that could authorize image sends.
  int _connectionGeneration = 0;
  final Map<int, int> _activeLoadingRefreshes = {};
  bool _connectionRefreshQueued = false;

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
  this : super(const SessionDetailState.loading()) {
    _streamingBuffer = StreamingTextBuffer(onFlush: _emitStreamingSnapshot);
    // Seed the connection state so the BehaviorSubject's immediate replay isn't
    // treated as a reconnect transition.
    _wasConnected = _connectionService.currentStatus is ConnectionConnected;
    _eventSubscription = _connectionService.sessionEvents(_sessionId).listen(_handleEvent);
    _globalEventSubscription = _connectionService.events.listen(_handleGlobalEvent);
    _connectionStatusSubscription = _connectionService.status.listen(_onConnectionStatusChanged);
    _staleSubscription = _connectionService.dataMayBeStale.listen(
      (_) => _onDataMayBeStale(trigger: _SessionRefreshTrigger.dataMayBeStale),
    );
    _lifecycleSubscription = _lifecycleSource.lifecycleStateStream.listen(_onLifecycleChanged);
    _loadMessages(isReload: false);
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<_SessionRefreshResult> _loadMessages({required bool isReload}) async {
    final connectionGeneration = _connectionGeneration;
    final deferredPartEventSequence = _deferredPartEvents.latestSequence;
    _activeLoadingRefreshes.update(connectionGeneration, (count) => count + 1, ifAbsent: () => 1);
    emit(const SessionDetailState.loading());
    late final SessionDetailLoadResult result;
    try {
      result = isReload
          ? await _loadService.reload(sessionId: _sessionId, projectId: _projectId)
          : await _loadService.load(sessionId: _sessionId, projectId: _projectId);
    } finally {
      final remaining = (_activeLoadingRefreshes[connectionGeneration] ?? 1) - 1;
      if (remaining == 0) {
        _activeLoadingRefreshes.remove(connectionGeneration);
      } else {
        _activeLoadingRefreshes[connectionGeneration] = remaining;
      }
    }
    if (isClosed) return _SessionRefreshResult.closed;

    if (connectionGeneration != _connectionGeneration) {
      if (_isConnected) {
        if (!_activeLoadingRefreshes.containsKey(_connectionGeneration)) {
          unawaited(_runLoadingRefresh(trigger: _SessionRefreshTrigger.connectionReconnected));
        }
      } else {
        _waitingForConnection = true;
      }
      return _SessionRefreshResult.staleConnection;
    }

    switch (result) {
      case SessionDetailLoadResultLoaded(:final snapshot):
        _waitingForConnection = false;
        _deferredPartEvents.discardForMessagesThrough(
          messageIds: snapshot.messages.map((message) => message.info.id),
          sequence: deferredPartEventSequence,
        );
        emit(_buildLoadedState(snapshot: snapshot));
        final effectiveProjectId = snapshot.projectId;
        if (effectiveProjectId == null || effectiveProjectId.isEmpty) {
          _projectViewingService.markClaimFailed(claim: _projectViewClaim);
        } else {
          _projectViewingService.markClaimReady(
            claim: _projectViewClaim,
            projectId: effectiveProjectId,
          );
        }
        // Declare the view only now that the transcript has actually loaded —
        // a load that fails or waits for connection must not mark the session
        // read (clearing its bold globally) while the user only saw a
        // loading/error state.
        _sessionViewingService.setViewingSession(_sessionId);
        _drainPendingEvents();
        _drainDeferredPartsForLoadedMessages();
        _tryDrainQueue();
        return _SessionRefreshResult.applied;
      case SessionDetailLoadResultWaitingForConnection():
        _projectViewingService.markClaimFailed(claim: _projectViewClaim);
        _waitingForConnection = true;
        if (_connectionService.currentStatus is ConnectionConnected) {
          _waitingForConnection = false;
          _logRefresh(
            action: _SessionRefreshAction.observed,
            trigger: _SessionRefreshTrigger.waitingForConnection,
          );
          unawaited(_runLoadingRefresh(trigger: _SessionRefreshTrigger.waitingForConnection));
        }
        return _SessionRefreshResult.waitingForConnection;
      case SessionDetailLoadResultFailed(:final error, :final stackTrace):
        _waitingForConnection = false;
        _projectViewingService.markClaimFailed(claim: _projectViewClaim);
        _pendingSessionEvents.clear();
        _pendingGlobalEvents.clear();
        _deferredPartEvents.clear();
        loge("Session detail load failed", error, stackTrace);
        emit(
          SessionDetailState.failed(
            reason: error is ApiError ? error.remoteFailureReason : RemoteFailureReason.unknown,
          ),
        );
        return _SessionRefreshResult.failed;
    }
  }

  Future<void> reload() async {
    await _loadMessages(isReload: true);
  }

  /// Loads the page of messages before the ones currently shown.
  ///
  /// A no-op when the start of the transcript is already loaded or a request
  /// is already running, so repeated scroll-to-top gestures cannot stack.
  Future<void> loadOlderMessages() async {
    final current = state;
    if (current is! SessionDetailLoaded) return;
    final cursor = current.olderMessagesCursor;
    if (cursor == null || current.isLoadingOlderMessages) return;

    final generation = _transcriptGeneration;
    final deferredPartEventSequence = _deferredPartEvents.latestSequence;
    emit(current.copyWith(isLoadingOlderMessages: true));
    final page = await _loadService.loadOlderMessages(sessionId: _sessionId, before: cursor);
    if (isClosed) return;

    final latest = state;
    if (latest is! SessionDetailLoaded) return;
    // A refresh may have replaced the transcript while this page was in
    // flight. This page describes the transcript as it was before that, so
    // prepending it would splice unrelated history onto the refreshed page,
    // leaving a gap. Compared by generation rather than by cursor value,
    // because a refresh can legitimately land on the same cursor.
    if (_transcriptGeneration != generation) return;

    if (page == null) {
      // Keep the cursor: the transcript did not end, the request failed, so
      // the user can retry.
      emit(latest.copyWith(isLoadingOlderMessages: false));
      return;
    }

    // Merge by id rather than concatenating. Live events can append a message
    // while the page is in flight, and an older page must never duplicate or
    // reorder what is already shown.
    final known = {for (final message in latest.messages) message.info.id};
    final older = [
      for (final message in page.messages)
        if (!known.contains(message.info.id)) message,
    ];
    _deferredPartEvents.discardForMessagesThrough(
      messageIds: page.messages.map((message) => message.info.id),
      sequence: deferredPartEventSequence,
    );
    emit(
      latest.copyWith(
        messages: [...older, ...latest.messages],
        olderMessagesCursor: page.olderMessagesCursor,
        isLoadingOlderMessages: false,
      ),
    );
    _drainDeferredPartsForLoadedMessages();
  }

  Future<void> _runLoadingRefresh({required _SessionRefreshTrigger trigger}) async {
    await _traceRefresh(
      trigger: trigger,
      operation: () => _loadMessages(isReload: true),
    );
  }

  void _silentRefresh({required _SessionRefreshTrigger trigger}) {
    if (state is! SessionDetailLoaded) {
      _logRefresh(action: _SessionRefreshAction.ignored, trigger: trigger);
      return;
    }
    final active = _activeRefresh;
    if (active != null) {
      _logRefresh(action: _SessionRefreshAction.coalesced, trigger: trigger);
      if (trigger == _SessionRefreshTrigger.connectionReconnected) {
        _queueConnectionRefreshAfter(activeRefresh: active);
      }
      // This call raced an in-flight refresh. If a staleness signal is
      // queued with no cooldown armed to drain it (the pause path cancels
      // the timer), chain the trailing refresh onto the in-flight completion
      // so the signal is never stranded.
      if (_eventRefreshQueued && _eventRefreshCooldown == null) {
        _drainQueueWhenRefreshCompletes(active);
      }
      return;
    }
    // Remove prior staleness from the live queue while this refresh runs.
    // Success consumes it; failure restores it. Signals that arrive while the
    // refresh is in flight independently re-queue behind it.
    final consumedQueuedSignal = _eventRefreshQueued;
    _eventRefreshQueued = false;
    late final Future<void> refresh;
    refresh = _traceRefresh(trigger: trigger, operation: _doSilentRefresh)
        .then((result) {
          if (result != _SessionRefreshResult.applied && consumedQueuedSignal) {
            _restoreQueuedRefreshAfterFailure();
          }
        })
        .whenComplete(() {
          if (identical(_activeRefresh, refresh)) {
            _activeRefresh = null;
          }
        });
    _activeRefresh = refresh;
  }

  void _restoreQueuedRefreshAfterFailure() {
    if (isClosed) return;
    _eventRefreshQueued = true;
    if (_wasPaused || state is! SessionDetailLoaded) return;
    if (!_isConnected) {
      _needsStaleRefresh = true;
      return;
    }
    _eventRefreshCooldown ??= Timer(eventRefreshMinInterval, _onEventRefreshCooldownElapsed);
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

  void _queueConnectionRefreshAfter({required Future<void> activeRefresh}) {
    if (_connectionRefreshQueued) return;
    _connectionRefreshQueued = true;
    unawaited(
      activeRefresh.whenComplete(() {
        if (!_connectionRefreshQueued) return;
        _connectionRefreshQueued = false;
        if (isClosed || !_isConnected || state is! SessionDetailLoaded) return;
        _silentRefresh(trigger: _SessionRefreshTrigger.connectionReconnected);
      }),
    );
  }

  /// Coalesces event-driven staleness signals (command.executed,
  /// dataMayBeStale) into at most one silent refresh per
  /// [eventRefreshMinInterval]. Repeated signals would otherwise each refetch
  /// the whole session snapshot — ~10 encrypted relay round-trips. The first
  /// signal after a quiet period still refreshes immediately; follow-ups within
  /// the cooldown collapse into a single trailing refresh. Reconnect and
  /// app-resume refreshes bypass this on purpose: they must run promptly and
  /// re-assert the bridge-side view declaration.
  void _requestEventDrivenRefresh({required _SessionRefreshTrigger trigger}) {
    _logRefresh(action: _SessionRefreshAction.observed, trigger: trigger);
    if (state is! SessionDetailLoaded) {
      _logRefresh(action: _SessionRefreshAction.ignored, trigger: trigger);
      return;
    }
    if (_wasPaused) {
      // Don't spend the radio while backgrounded: hold the signal and let
      // the resume path's bypass refresh consume it.
      _queueEventRefresh(trigger: trigger);
      return;
    }
    if (_eventRefreshCooldown != null) {
      _queueEventRefresh(trigger: trigger);
      return;
    }
    if (_activeRefresh != null) {
      // A refresh is already in flight (e.g. the reconnect path): its
      // snapshot may predate this signal, so queue a trailing refresh behind
      // a cooldown window instead of letting _silentRefresh coalesce the
      // signal into the stale in-flight run.
      _queueEventRefresh(trigger: trigger);
      _eventRefreshCooldown = Timer(eventRefreshMinInterval, _onEventRefreshCooldownElapsed);
      return;
    }
    _eventRefreshQueued = true;
    _silentRefresh(trigger: trigger);
    _eventRefreshCooldown = Timer(eventRefreshMinInterval, _onEventRefreshCooldownElapsed);
  }

  void _queueEventRefresh({required _SessionRefreshTrigger trigger}) {
    final action = _eventRefreshQueued ? _SessionRefreshAction.coalesced : _SessionRefreshAction.queued;
    _eventRefreshQueued = true;
    _logRefresh(action: action, trigger: trigger);
  }

  void _onEventRefreshCooldownElapsed() {
    _eventRefreshCooldown = null;
    if (!_eventRefreshQueued) return;
    if (isClosed || state is! SessionDetailLoaded) {
      _eventRefreshQueued = false;
      _logRefresh(
        action: _SessionRefreshAction.ignored,
        trigger: _SessionRefreshTrigger.queuedEvent,
      );
      return;
    }
    // While backgrounded the queue is held for the resume bypass refresh.
    if (_wasPaused) return;
    if (!_isConnected) {
      _needsStaleRefresh = true;
      _logRefresh(
        action: _SessionRefreshAction.queued,
        trigger: _SessionRefreshTrigger.queuedEvent,
      );
      return;
    }
    final active = _activeRefresh;
    if (active != null) {
      _logRefresh(
        action: _SessionRefreshAction.coalesced,
        trigger: _SessionRefreshTrigger.queuedEvent,
      );
      // The minimum interval has already elapsed, so run the queued refresh
      // as soon as the in-flight one completes instead of waiting another
      // full window.
      _drainQueueWhenRefreshCompletes(active);
      return;
    }
    _logRefresh(
      action: _SessionRefreshAction.observed,
      trigger: _SessionRefreshTrigger.queuedEvent,
    );
    _silentRefresh(trigger: _SessionRefreshTrigger.queuedEvent);
    _eventRefreshCooldown = Timer(eventRefreshMinInterval, _onEventRefreshCooldownElapsed);
  }

  Future<_SessionRefreshResult> _doSilentRefresh() async {
    final current = state;
    if (current is! SessionDetailLoaded) return _SessionRefreshResult.closed;
    final connectionGeneration = _connectionGeneration;
    final commandCatalogGeneration = _commandCatalogGeneration;
    final deferredPartEventSequence = _deferredPartEvents.latestSequence;

    emit(
      current.copyWith(
        isRefreshing: true,
        queuedMessages: _promptQueue.items,
        sendingSubmission: _promptQueue.active,
      ),
    );

    try {
      final result = await _loadService.reload(sessionId: _sessionId, projectId: _projectId);
      if (isClosed) return _SessionRefreshResult.closed;
      if (connectionGeneration != _connectionGeneration) {
        final latest = state;
        if (latest is SessionDetailLoaded) {
          emit(
            latest.copyWith(
              isRefreshing: false,
              queuedMessages: _promptQueue.items,
              sendingSubmission: _promptQueue.active,
            ),
          );
        }
        return _SessionRefreshResult.staleConnection;
      }

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
          if (latest is! SessionDetailLoaded) return _SessionRefreshResult.closed;
          final preservedSelectedAgent = latest.selectedAgent;
          final preservedSelectedAgentModel = latest.selectedAgentModel;
          final preservedStagedCommand = latest.stagedCommand;
          final availableCommands = commandCatalogGeneration == _commandCatalogGeneration
              ? snapshot.commands
              : latest.availableCommands;
          final availableVariants = _deriveAvailableVariants(
            providers: availableProviders,
            model: preservedSelectedAgentModel,
          );
          _reconcileStagedWithSnapshot(snapshot: snapshot);

          final refreshedSessionStatus = snapshot.statuses[_sessionId] ?? const SessionStatus.idle();
          final retryMessage = switch (refreshedSessionStatus) {
            SessionStatusRetry(:final message) => message,
            SessionStatusIdle() => null,
            SessionStatusBusy() => null,
          };

          // The transcript is being replaced wholesale, so any older-page
          // request still in flight no longer joins onto it.
          _deferredPartEvents.discardForMessagesThrough(
            messageIds: snapshot.messages.map((message) => message.info.id),
            sequence: deferredPartEventSequence,
          );
          _transcriptGeneration++;
          emit(
            latest.copyWith(
              messages: snapshot.messages,
              // A refresh re-reads the newest page, so previously paged-back
              // history is dropped and the cursor returns to that page's edge.
              // Keeping older pages would leave a gap between them and the
              // refreshed page whenever the session moved on meanwhile.
              olderMessagesCursor: snapshot.olderMessagesCursor,
              isLoadingOlderMessages: false,
              streamingText: streamingText,
              sessionStatus: refreshedSessionStatus,
              retryErrorMessage: retryMessage,
              pendingQuestions: _mapPendingQuestions(snapshot.pendingQuestions),
              pendingPermissions: _mapPendingPermissions(snapshot.pendingPermissions),
              bridgeQueuedPrompts: snapshot.bridgeQueuedPrompts,
              agent: latestAssistant?.agent,
              assistantAgentModel: assistantAgentModel,
              children: refreshedChildSessions,
              childStatuses: childStatuses,
              isArchived: snapshot.isArchived,
              availableAgents: availableAgents,
              availableProviders: availableProviders,
              availableCommands: availableCommands,
              supportsPromptAttachments: snapshot.supportsPromptAttachments,
              sessionTitle: snapshot.canonicalSessionTitle ?? latest.sessionTitle,
              selectedAgent: preservedSelectedAgent,
              selectedAgentModel: preservedSelectedAgentModel,
              stagedCommand: _resolveStagedCommand(
                availableCommands: availableCommands,
                stagedCommand: preservedStagedCommand,
              ),
              queuedMessages: _visibleStagedItems(bridgePrompts: snapshot.bridgeQueuedPrompts),
              sendingSubmission: _visibleStagedSending(bridgePrompts: snapshot.bridgeQueuedPrompts),
              isRefreshing: false,
              availableVariants: availableVariants,
            ),
          );
          _tryDrainQueue();
          if (_reassertViewAfterRefresh) {
            // A resume/reconnect requested this refresh; the refreshed
            // transcript has rendered, so it is safe to re-declare the view
            // (which marks the session seen on the bridge).
            _reassertViewAfterRefresh = false;
            _sessionViewingService.setViewingSession(_sessionId);
          }
          _drainPendingEvents();
          _drainDeferredPartsForLoadedMessages();
          return _SessionRefreshResult.applied;
        case SessionDetailLoadResultWaitingForConnection():
          _waitingForConnection = true;
          final latest = state;
          if (latest is SessionDetailLoaded) {
            emit(
              latest.copyWith(
                isRefreshing: false,
                queuedMessages: _promptQueue.items,
                sendingSubmission: _promptQueue.active,
              ),
            );
          }
          return _SessionRefreshResult.waitingForConnection;
        case SessionDetailLoadResultFailed(:final error, :final stackTrace):
          logw("Silent refresh failed", error, stackTrace);
          final latest = state;
          if (latest is SessionDetailLoaded) {
            emit(
              latest.copyWith(
                isRefreshing: false,
                queuedMessages: _promptQueue.items,
                sendingSubmission: _promptQueue.active,
              ),
            );
          }
          return _SessionRefreshResult.failed;
      }
    } on Object catch (error, stackTrace) {
      logw("Silent refresh failed", error, stackTrace);
      if (isClosed) return _SessionRefreshResult.closed;
      final latest = state;
      if (latest is SessionDetailLoaded) {
        emit(
          latest.copyWith(
            isRefreshing: false,
            queuedMessages: _promptQueue.items,
            sendingSubmission: _promptQueue.active,
          ),
        );
      }
      return _SessionRefreshResult.failed;
    }
  }

  Future<_SessionRefreshResult> _traceRefresh({
    required _SessionRefreshTrigger trigger,
    required Future<_SessionRefreshResult> Function() operation,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logRefresh(action: _SessionRefreshAction.started, trigger: trigger);
    final result = await operation();
    stopwatch.stop();
    final resultValue = switch (result) {
      _SessionRefreshResult.applied => "applied",
      _SessionRefreshResult.failed => "failed",
      _SessionRefreshResult.waitingForConnection => "waiting_for_connection",
      _SessionRefreshResult.staleConnection => "stale_connection",
      _SessionRefreshResult.closed => "closed",
    };
    logd(
      "[session-refresh] action=${_SessionRefreshAction.completed.name} "
      "trigger=${trigger.logValue} result=$resultValue durationMs=${stopwatch.elapsedMilliseconds}",
    );
    return result;
  }

  void _logRefresh({
    required _SessionRefreshAction action,
    required _SessionRefreshTrigger trigger,
  }) {
    logd("[session-refresh] action=${action.name} trigger=${trigger.logValue}");
  }

  void _onCommandCatalogUpdated({required String pluginId}) {
    final current = state;
    if (current is! SessionDetailLoaded || current.pluginId != pluginId) return;
    final generation = ++_commandCatalogGeneration;
    unawaited(_refreshCommandCatalog(pluginId: pluginId, generation: generation));
  }

  Future<void> _refreshCommandCatalog({required String pluginId, required int generation}) async {
    try {
      final response = await _sessionRepository.listCommands(projectId: _projectId, pluginId: pluginId);
      if (isClosed || generation != _commandCatalogGeneration) return;
      switch (response) {
        case SuccessResponse(:final data):
          final latest = state;
          if (latest is! SessionDetailLoaded || latest.pluginId != pluginId) return;
          emit(
            latest.copyWith(
              availableCommands: data.items,
              stagedCommand: _resolveStagedCommand(
                availableCommands: data.items,
                stagedCommand: latest.stagedCommand,
              ),
            ),
          );
        case ErrorResponse(:final error):
          logw("Failed to refresh command catalog", error);
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to refresh command catalog", error, stackTrace);
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
          _onDataMayBeStale(trigger: _SessionRefreshTrigger.commandExecuted);
        case SesoriSessionPromptDefaultsChanged(:final promptDefaults):
          _onPromptDefaultsChanged(promptDefaults);
        case SesoriSessionQueuedPrompts(:final prompts):
          _onBridgeQueueUpdated(prompts);
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
      SesoriPermissionAsked(:final sessionID, :final displaySessionId) => _surfacesChildRequestHere(
        sessionID: sessionID,
        displaySessionId: displaySessionId,
      ),
      SesoriPermissionReplied(:final sessionID, :final displaySessionId) => _surfacesChildRequestHere(
        sessionID: sessionID,
        displaySessionId: displaySessionId,
      ),
      SesoriQuestionAsked(:final sessionID, :final displaySessionId) => _surfacesChildRequestHere(
        sessionID: sessionID,
        displaySessionId: displaySessionId,
      ),
      SesoriQuestionReplied(:final sessionID, :final displaySessionId) => _surfacesChildRequestHere(
        sessionID: sessionID,
        displaySessionId: displaySessionId,
      ),
      SesoriQuestionRejected(:final sessionID, :final displaySessionId) => _surfacesChildRequestHere(
        sessionID: sessionID,
        displaySessionId: displaySessionId,
      ),
      // The loaded session identifies its plugin after the initial snapshot,
      // so retain catalog invalidations until that scope can be matched.
      SesoriCommandCatalogUpdated() => true,
      // Definitively irrelevant high-volume events.
      SesoriServerConnected() ||
      SesoriServerHeartbeat() ||
      SesoriServerInstanceDisposed() ||
      SesoriGlobalDisposed() ||
      SesoriCatalogImportProgress() ||
      SesoriPluginManagementChanged() ||
      SesoriPluginInstallProgress() ||
      SesoriPluginAuthenticationProgress() ||
      SesoriSessionsUpdated() ||
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
      // Queued prompts render only for the session itself; own-session events
      // arrive through the session-scoped stream, not this global path.
      SesoriSessionQueuedPrompts() ||
      // Unseen-state changes are list-level concerns handled by the tracker;
      // the detail screen does not react to them.
      SesoriSessionUnseenChanged() => false,
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
        case SesoriCommandCatalogUpdated(:final pluginId):
          _onCommandCatalogUpdated(pluginId: pluginId);
        case SesoriSessionCreated() ||
            SesoriSessionDeleted() ||
            SesoriSessionDiff() ||
            SesoriSessionError() ||
            SesoriSessionCompacted() ||
            SesoriServerConnected() ||
            SesoriServerHeartbeat() ||
            SesoriServerInstanceDisposed() ||
            SesoriGlobalDisposed() ||
            SesoriCatalogImportProgress() ||
            SesoriPluginManagementChanged() ||
            SesoriPluginInstallProgress() ||
            SesoriPluginAuthenticationProgress() ||
            SesoriSessionsUpdated() ||
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
            SesoriSessionQueuedPrompts() ||
            SesoriSessionPromptDefaultsChanged():
          break;
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
    final sessionTime = session.time;

    if (isClosed) return;
    emit(
      current.copyWith(
        sessionTitle: session.title,
        isArchived: sessionTime == null ? current.isArchived : sessionTime.archived != null,
      ),
    );
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
      final entry = MessageWithParts(info: message, parts: const []);
      final insertionIndex = _messageInsertionIndex(messages: messages, message: message);
      messages.insert(insertionIndex, entry);
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
    } else if (message case MessageUser(promptId: final promptId?)) {
      // The queued bubble transforms into this message: dropping the entry in
      // the same emission as the message upsert means no frame ever shows
      // both (or neither). Any stale local copy of the same prompt (a send
      // whose response was lost) is healed here too.
      _promptQueue.removeByPromptId(promptId);
      final bridgePrompts = [
        for (final prompt in current.bridgeQueuedPrompts)
          if (prompt.id != promptId) prompt,
      ];
      emit(
        current.copyWith(
          messages: messages,
          bridgeQueuedPrompts: bridgePrompts,
          queuedMessages: _visibleStagedItems(bridgePrompts: bridgePrompts),
          sendingSubmission: _visibleStagedSending(bridgePrompts: bridgePrompts),
        ),
      );
      // The healed prompt's own send may have stopped the drain on a lost
      // response; anything staged behind it must not stay parked.
      _tryDrainQueue();
    } else {
      emit(current.copyWith(messages: messages));
    }
    _drainDeferredPartsForMessage(messageId: message.id);
  }

  /// Applies a full-list replacement of the bridge-owned queue. Local staged
  /// sends the bridge now owns leave the display in the same emission (covers
  /// the event racing ahead of the acceptance response).
  void _onBridgeQueueUpdated(List<QueuedSessionPrompt> prompts) {
    if (isClosed) return;
    final current = state;
    if (current is! SessionDetailLoaded) return;
    for (final prompt in prompts) {
      _promptQueue.removeByPromptId(prompt.id);
    }
    emit(
      current.copyWith(
        bridgeQueuedPrompts: prompts,
        queuedMessages: _visibleStagedItems(bridgePrompts: prompts),
        sendingSubmission: _visibleStagedSending(bridgePrompts: prompts),
      ),
    );
  }

  /// Cancels a bridge-queued prompt. The entry leaves the state on the
  /// bridge's confirmation — including not-found, which means it already
  /// dispatched or was removed elsewhere; only a transport failure keeps it.
  Future<void> cancelBridgeQueuedPrompt({required String promptId}) async {
    final result = await _sessionRepository.cancelQueuedPrompt(sessionId: _sessionId, promptId: promptId);
    // Only not-found means the entry is gone (dispatched or removed
    // elsewhere); any other failure proves nothing about the bridge queue.
    if (result case ErrorResponse(:final error)) {
      if (error is! NonSuccessCodeError || error.errorCode != 404) return;
    }
    _promptQueue.removeByPromptId(promptId);
    final current = state;
    if (current is! SessionDetailLoaded || isClosed) return;
    final bridgePrompts = [
      for (final prompt in current.bridgeQueuedPrompts)
        if (prompt.id != promptId) prompt,
    ];
    emit(
      current.copyWith(
        bridgeQueuedPrompts: bridgePrompts,
        queuedMessages: _visibleStagedItems(bridgePrompts: bridgePrompts),
        sendingSubmission: _visibleStagedSending(bridgePrompts: bridgePrompts),
      ),
    );
  }

  int _messageInsertionIndex({required List<MessageWithParts> messages, required Message message}) {
    final created = message.time?.created;
    if (created == null) return messages.length;
    for (var index = 0; index < messages.length; index++) {
      final existing = messages[index].info;
      final existingCreated = existing.time?.created;
      if (existingCreated == null) continue;
      if (existingCreated > created) {
        return index;
      }
    }
    return messages.length;
  }

  void _onMessageRemoved(String messageId) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final messages = current.messages.where((item) => item.info.id != messageId).toList();
    _deferredPartEvents.removeMessage(messageId: messageId);

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

    if (messageIndex < 0) {
      _deferredPartEvents.deferUpdated(part: part);
      if (isClosed) return;
      emit(current.copyWith(streamingText: _streamingBuffer.snapshot()));
      return;
    }

    final message = messages[messageIndex];
    final parts = List<MessagePart>.from(message.parts);
    final partIndex = parts.indexWhere((item) => item.id == part.id);

    if (partIndex >= 0) {
      parts[partIndex] = part;
    } else {
      parts.add(part);
    }

    messages[messageIndex] = message.copyWith(parts: parts);

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

    if (messageIndex < 0) {
      _deferredPartEvents.deferRemoved(
        sessionId: _sessionId,
        messageId: messageId,
        partId: partId,
      );
      if (isClosed) return;
      emit(current.copyWith(streamingText: _streamingBuffer.snapshot()));
      return;
    }

    final message = messages[messageIndex];
    final parts = message.parts.where((item) => item.id != partId).toList();
    messages[messageIndex] = message.copyWith(parts: parts);

    if (isClosed) return;
    emit(
      current.copyWith(
        messages: messages,
        streamingText: _streamingBuffer.snapshot(),
      ),
    );
  }

  void _drainDeferredPartsForMessage({required String messageId}) {
    final events = _deferredPartEvents.takeForMessage(messageId: messageId);
    events.forEach(_processSessionEvent);
  }

  void _drainDeferredPartsForLoadedMessages() {
    final current = state;
    if (current is! SessionDetailLoaded) return;
    final knownMessageIds = current.messages.map((message) => message.info.id).toSet();
    final readyMessageIds = _deferredPartEvents.messageIds.where(knownMessageIds.contains).toList();
    for (final messageId in readyMessageIds) {
      _drainDeferredPartsForMessage(messageId: messageId);
    }
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

  void _onDataMayBeStale({required _SessionRefreshTrigger trigger}) {
    if (state is! SessionDetailLoaded) {
      _logRefresh(action: _SessionRefreshAction.observed, trigger: trigger);
      _logRefresh(action: _SessionRefreshAction.ignored, trigger: trigger);
      return;
    }
    final status = _connectionService.status.value;
    if (status is ConnectionConnected) {
      _requestEventDrivenRefresh(trigger: trigger);
    } else {
      _logRefresh(action: _SessionRefreshAction.observed, trigger: trigger);
      _logRefresh(action: _SessionRefreshAction.queued, trigger: trigger);
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
        const trigger = _SessionRefreshTrigger.lifecycleResumed;
        _logRefresh(action: _SessionRefreshAction.observed, trigger: trigger);
        _wasPaused = false;
        if (state is! SessionDetailLoaded) {
          _logRefresh(action: _SessionRefreshAction.ignored, trigger: trigger);
          return;
        }
        // The viewing service cleared the view on background and does not
        // re-assert on its own; refresh so the transcript reflects activity
        // that arrived while hidden, then re-declare the view once the refresh
        // renders. When disconnected, defer to the reconnect path below.
        _reassertViewAfterRefresh = true;
        if (_isConnected) {
          _silentRefresh(trigger: trigger);
        } else {
          _logRefresh(action: _SessionRefreshAction.queued, trigger: trigger);
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
    if (!isConnected && _wasConnected) _connectionGeneration++;
    _wasConnected = isConnected;
    if (!isConnected) {
      _connectionRefreshQueued = false;
      final current = state;
      if (current is SessionDetailLoaded && current.supportsPromptAttachments != null) {
        // Plugin capabilities belong to the bridge behind the connection and
        // must be resolved again before another bridge can receive images.
        emit(current.copyWith(supportsPromptAttachments: null));
      }
      return;
    }
    if (_waitingForConnection) {
      _waitingForConnection = false;
      const trigger = _SessionRefreshTrigger.waitingForConnection;
      _logRefresh(action: _SessionRefreshAction.observed, trigger: trigger);
      unawaited(_runLoadingRefresh(trigger: trigger));
      return;
    }
    _tryDrainQueue();
    if (_needsStaleRefresh) {
      _needsStaleRefresh = false;
      const trigger = _SessionRefreshTrigger.connectionReconnected;
      _logRefresh(action: _SessionRefreshAction.observed, trigger: trigger);
      // The disconnect that queued this refresh also released this
      // connection's view on the bridge, so re-assert it once the refresh
      // renders — same as the plain reconnect branch below.
      if (state is SessionDetailLoaded) _reassertViewAfterRefresh = true;
      _silentRefresh(trigger: trigger);
    } else if (reconnected && state is SessionDetailLoaded) {
      const trigger = _SessionRefreshTrigger.connectionReconnected;
      _logRefresh(action: _SessionRefreshAction.observed, trigger: trigger);
      // A foreground relay reconnect: the bridge released the old
      // connection's view declaration, so refresh and re-assert it.
      _reassertViewAfterRefresh = true;
      _silentRefresh(trigger: trigger);
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

  Future<void> sendMessage({
    required String text,
    required String? command,
    required ComposerInputMode inputMode,
    required List<ComposerAttachment> attachments,
  }) async {
    final current = state;
    final trimmed = text.trim();
    final normalizedCommand = command?.normalize();
    if (trimmed.isEmpty && normalizedCommand == null && attachments.isEmpty) return;

    if (_refuseWhenArchived(action: "send a prompt")) return;

    // The bridge's command paths carry only the text part, so sending this
    // combination would drop the images without telling anyone. Refuse it at
    // the seam that formats the wire payload, not only in the composer.
    if (normalizedCommand != null && attachments.isNotEmpty) {
      logw("Refused a /$normalizedCommand submission carrying ${attachments.length} attachment(s)");
      return;
    }

    // Hold the declared capability line at the wire seam too. An unresolved
    // capability refuses as well, so unsupported images never enter the queue.
    final supportsPromptAttachments = current is SessionDetailLoaded ? current.supportsPromptAttachments : null;
    if (attachments.isNotEmpty && supportsPromptAttachments != true) {
      logw("Refused ${attachments.length} attachment(s) because plugin support is unavailable");
      return;
    }

    final selectedAgent = current is SessionDetailLoaded ? current.selectedAgent : null;
    final selectedAgentModel = current is SessionDetailLoaded ? current.selectedAgentModel : null;
    // The id survives retries of the same submission, so a send whose
    // response was lost re-lands on the bridge as an idempotent no-op.
    final promptId = _generatePromptId();
    final submission = normalizedCommand == null
        ? QueuedSessionSubmission.text(
            promptId: promptId,
            text: trimmed,
            inputMode: inputMode,
            attachments: attachments,
            agent: selectedAgent,
            agentModel: selectedAgentModel,
          )
        : QueuedSessionSubmission.command(
            promptId: promptId,
            text: trimmed,
            command: normalizedCommand,
            agent: selectedAgent,
            agentModel: selectedAgentModel,
          );
    _promptQueue.enqueue(submission);
    _emitQueueUpdate(current is SessionDetailLoaded ? current : null);
    if (_isConnected && current is SessionDetailLoaded) await _drainQueuedMessages();
  }

  void cancelQueuedMessage(int index) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final removed = _promptQueue.cancel(index);
    if (removed != null) {
      _emitQueueUpdate(current);
      _tryDrainQueue();
    }
  }

  /// Syncs queued prompt items into the cubit state.
  void _emitQueueUpdate([SessionDetailLoaded? known]) {
    if (isClosed) return;
    final current = known ?? state;
    if (current is! SessionDetailLoaded) return;
    emit(
      current.copyWith(
        queuedMessages: _visibleStagedItems(bridgePrompts: current.bridgeQueuedPrompts),
        sendingSubmission: _visibleStagedSending(bridgePrompts: current.bridgeQueuedPrompts),
      ),
    );
  }

  /// Drops staged copies a fresh snapshot proves the bridge already owns —
  /// listed in its queue or landed as a user message with the same prompt id.
  void _reconcileStagedWithSnapshot({required SessionDetailSnapshot snapshot}) {
    for (final prompt in snapshot.bridgeQueuedPrompts) {
      _promptQueue.removeByPromptId(prompt.id);
    }
    for (final message in snapshot.messages) {
      if (message.info case MessageUser(promptId: final promptId?)) {
        _promptQueue.removeByPromptId(promptId);
      }
    }
  }

  /// Staged sends not yet owned by the bridge. A staged copy whose id the
  /// bridge queue already lists renders nowhere; its in-flight send settles
  /// (or its idempotent retry no-ops) without a second bubble.
  List<QueuedSessionSubmission> _visibleStagedItems({required List<QueuedSessionPrompt> bridgePrompts}) {
    if (bridgePrompts.isEmpty) return _promptQueue.items;
    final bridgeIds = {for (final prompt in bridgePrompts) prompt.id};
    return [
      for (final item in _promptQueue.items)
        if (!bridgeIds.contains(item.promptId)) item,
    ];
  }

  QueuedSessionSubmission? _visibleStagedSending({required List<QueuedSessionPrompt> bridgePrompts}) {
    final active = _promptQueue.active;
    if (active == null || _promptQueue.isActiveSettledElsewhere) return null;
    return bridgePrompts.any((prompt) => prompt.id == active.promptId) ? null : active;
  }

  Future<void> _drainQueuedMessages() async {
    if (_promptQueue.isSending) return;
    final current = state;
    if (current is! SessionDetailLoaded) return;
    if (!_isConnected) return;
    if (_refuseWhenArchived(action: "drain the prompt queue")) return;

    final pendingSubmission = _promptQueue.items.firstOrNull;
    if (pendingSubmission == null) return;
    if (pendingSubmission.attachments.isNotEmpty && current.supportsPromptAttachments != true) {
      // Preserve authored FIFO order: the blocked image stays visible and
      // cancellable rather than allowing later text prompts to overtake it.
      return;
    }
    final submission = _promptQueue.beginSend();
    if (submission == null) return;
    final sendConnectionGeneration = _connectionGeneration;

    _emitQueueUpdate(current);

    var sendSucceeded = false;
    var sendSettledElsewhere = false;
    try {
      final result = await _sessionRepository.sendMessage(
        sessionId: _sessionId,
        promptId: submission.promptId,
        text: submission.text,
        attachments: submission.attachments,
        agent: submission.agent,
        model: _agentModelToPromptModel(submission.agentModel),
        variant: switch (submission.agentModel?.variant) {
          null => null,
          final variant => SessionVariant(id: variant),
        },
        command: submission.command,
      );

      switch (result) {
        case SuccessResponse():
          sendSucceeded = true;
          _promptQueue.completeSend();
          _reportAcceptedSubmission(submission: submission);
        case ErrorResponse():
          sendSettledElsewhere = !_promptQueue.failSend();
      }
    } on Object catch (error, stackTrace) {
      sendSettledElsewhere = !_promptQueue.failSend();
      logw("Failed to send queued session submission", error, stackTrace);
    }

    _emitQueueUpdate(_latestLoadedState());

    if (sendSettledElsewhere && _isConnected) {
      // The bridge already owns that prompt; the staged sends behind it must
      // not stay parked on its moot transport failure.
      unawaited(_drainQueuedMessages());
      return;
    }
    if (!sendSucceeded && sendConnectionGeneration != _connectionGeneration && _isConnected) {
      unawaited(_drainQueuedMessages());
      return;
    }
    if (sendSucceeded) {
      final latest = state;
      if (latest is SessionDetailLoaded && _isConnected) {
        unawaited(_drainQueuedMessages());
      }
    }
  }

  ComposerDraft get composerDraft => _composerDraft;

  void saveComposerDraft({required ComposerDraft draft}) {
    _composerDraft = draft;
    _composerDraftRepository.saveForSession(sessionId: _sessionId, draft: draft);
  }

  void clearComposerDraft() {
    _composerDraft = ComposerDraft.typed(text: "");
    _composerDraftRepository.clearForSession(sessionId: _sessionId);
  }

  void reportVoiceTranscriptionCompleted() {
    _reportProductEvent(event: const ProductAnalyticsEvent.voiceTranscriptionCompleted());
  }

  void _reportAcceptedSubmission({required QueuedSessionSubmission submission}) {
    final analyticsSubmission = switch (submission) {
      QueuedTextSubmission(:final inputMode) => AnalyticsSubmission.text(
        inputMode: _analyticsInputMode(inputMode),
      ),
      QueuedCommandSubmission() => const AnalyticsSubmission.command(),
    };
    _reportProductEvent(
      event: ProductAnalyticsEvent.sessionMessageSent(submission: analyticsSubmission),
    );
  }

  AnalyticsInputMode _analyticsInputMode(ComposerInputMode inputMode) => switch (inputMode) {
    ComposerInputMode.typed => AnalyticsInputMode.typed,
    ComposerInputMode.voiceAssisted => AnalyticsInputMode.voiceAssisted,
  };

  static final Random _promptIdRandom = Random.secure();

  /// Client-generated prompt identity, mirroring the bridge's `prm_` shape.
  static String _generatePromptId() {
    final buffer = StringBuffer("prm_");
    for (var index = 0; index < 16; index++) {
      buffer.write(_promptIdRandom.nextInt(256).toRadixString(16).padLeft(2, "0"));
    }
    return buffer.toString();
  }

  void _reportProductEvent({required ProductAnalyticsEvent event}) {
    unawaited(
      _productAnalyticsService
          .logEvent(event: event, occurredAtUtc: DateTime.now().toUtc())
          .then<void>((result) {
            if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver session outcome analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report session outcome analytics event", error, stackTrace);
          }),
    );
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

  /// Archiving is permanent, so an archived session is audit-only: every
  /// mutation refuses here rather than in the widgets. Returns `true` when the
  /// caller must stop.
  bool _refuseWhenArchived({required String action}) {
    final current = state;
    if (current is! SessionDetailLoaded || !current.isArchived) return false;
    logw("Refused to $action for archived session $_sessionId");
    return true;
  }

  Future<bool> replyToQuestion({
    required String requestId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) async {
    if (_refuseWhenArchived(action: "reply to a question")) return false;

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
      _reportProductEvent(event: const ProductAnalyticsEvent.sessionQuestionAnswered());
      return true;
    } on Object catch (e, st) {
      loge("Failed to reply to question $requestId", e, st);
      await _loadMessages(isReload: true);
      return false;
    }
  }

  Future<bool> rejectQuestion(String requestId) async {
    if (_refuseWhenArchived(action: "reject a question")) return false;

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
      _reportProductEvent(event: const ProductAnalyticsEvent.sessionQuestionRejected());
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
    if (_refuseWhenArchived(action: "reply to a permission")) return false;

    _onPermissionResolved(requestId);
    _notificationCanceller.cancelForSession(sessionId: sessionId);
    try {
      final result = await _permissionRepository.replyToPermission(
        requestId: requestId,
        sessionId: sessionId,
        reply: reply,
      );
      switch (result) {
        case SuccessResponse():
          _reportProductEvent(
            event: ProductAnalyticsEvent.sessionPermissionAnswered(
              decision: _analyticsPermissionDecision(reply: reply),
            ),
          );
          return true;
        case ErrorResponse(:final error):
          throw error;
      }
    } on Object catch (e, st) {
      loge("Failed to reply to permission $requestId", e, st);
      await _loadMessages(isReload: true);
      return false;
    }
  }

  AnalyticsPermissionDecision _analyticsPermissionDecision({required PermissionReply reply}) => switch (reply) {
    PermissionReply.once => AnalyticsPermissionDecision.once,
    PermissionReply.always => AnalyticsPermissionDecision.always,
    PermissionReply.reject => AnalyticsPermissionDecision.reject,
  };

  // ---------------------------------------------------------------------------
  // Settings & control
  // ---------------------------------------------------------------------------

  void selectAgent(String agent) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final agentInfo = current.availableAgents.firstWhereOrNull((a) => a.name == agent);
    if (agentInfo == null) return;
    // A null model means this agent has no model preference of its own.
    final agentModel = agentInfo.model ?? current.selectedAgentModel;

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
      // Stop means "run nothing further": staged local sends must not fire on
      // the next drain. The bridge clears its own queue as part of the abort.
      if (_promptQueue.isNotEmpty || _promptQueue.isSending) {
        _promptQueue.clear();
        _emitQueueUpdate(current is SessionDetailLoaded ? current : null);
      }
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
      _reportProductEvent(event: const ProductAnalyticsEvent.sessionAbortSucceeded());
    } on Object catch (e, st) {
      loge("Failed to abort session(s)", e, st);
    }
  }

  SessionDetailLoaded _buildLoadedState({required SessionDetailSnapshot snapshot}) {
    _reconcileStagedWithSnapshot(snapshot: snapshot);
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
          defaultModelID: provider.defaultModelID,
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

    _transcriptGeneration++;
    return SessionDetailLoaded(
      messages: snapshot.messages,
      olderMessagesCursor: snapshot.olderMessagesCursor,
      streamingText: const {},
      sessionStatus: initialSessionStatus,
      retryErrorMessage: initialRetryMessage,
      pendingQuestions: _mapPendingQuestions(snapshot.pendingQuestions),
      pendingPermissions: _mapPendingPermissions(snapshot.pendingPermissions),
      bridgeQueuedPrompts: snapshot.bridgeQueuedPrompts,
      sessionTitle: snapshot.canonicalSessionTitle,
      pluginId: snapshot.pluginId,
      supportsPromptAttachments: snapshot.supportsPromptAttachments,
      agent: latestAssistant?.agent,
      assistantAgentModel: assistantAgentModel,
      children: childSessions,
      childStatuses: childStatuses,
      isRootSession: snapshot.isRootSession,
      isArchived: snapshot.isArchived,
      queuedMessages: _visibleStagedItems(bridgePrompts: snapshot.bridgeQueuedPrompts),
      sendingSubmission: _visibleStagedSending(bridgePrompts: snapshot.bridgeQueuedPrompts),
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
            allowAlways: p.allowAlways,
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
    _projectViewingService.releaseClaim(claim: _projectViewClaim);
    _pendingSessionEvents.clear();
    _pendingGlobalEvents.clear();
    _deferredPartEvents.clear();
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

import "dart:async";
import "dart:math";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/session_api.dart" show SessionAbortApiRejectedException;
import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../foundation/models/composer/composer_attachment.dart";
import "../../foundation/models/composer/composer_draft.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../foundation/models/session_options/session_options_request_mode.dart";
import "../../logging/logging.dart";
import "../../platform/lifecycle_source.dart";
import "../../platform/notification_canceller.dart";
import "../../repositories/composer_draft_repository.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../repositories/models/session_options_repository_result.dart";
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
import "session_abort_outcome.dart";
import "session_detail_notice.dart";
import "session_detail_resolvers.dart";
import "session_detail_state.dart";
import "streaming_text_buffer.dart";

enum _SessionRefreshTrigger(final String logValue) {
  commandExecuted("command_executed"),
  connectionReconnected("connection_reconnected"),
  lifecycleResumed("lifecycle_resumed"),
  dataMayBeStale("data_may_be_stale"),
  waitingForConnection("waiting_for_connection"),
  queuedEvent("queued_event"),
}

enum _SessionRefreshAction() {
  observed,
  ignored,
  queued,
  coalesced,
  started,
  completed,
}

enum _SessionRefreshResult() {
  applied,
  failed,
  waitingForConnection,
  staleConnection,
  closed,
}

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
  required final NotificationCanceller? _notificationCanceller,
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
  final Set<String> _staleOptionsRecoveryAttemptedPromptIds = {};

  /// Monotonic counter stamped on parked sends, so a snapshot can settle only
  /// the parked prompts its fetch actually had a chance to observe.
  int _parkEpoch = 0;

  /// Delivered user messages already accounted for. A message becomes
  /// renderable through its envelope and then each of its parts, so without
  /// this every update would settle another prompt.
  final Set<({String messageId, String? promptId})> _accountedUserMessages = {};
  final DeferredPartEventBuffer _deferredPartEvents = DeferredPartEventBuffer();

  final CompositeSubscription _subscriptions = CompositeSubscription();
  late final StreamingTextBuffer _streamingBuffer;
  Future<void>? _activeRefresh;
  int _commandCatalogGeneration = 0;
  Timer? _eventRefreshCooldown;
  bool _eventRefreshQueued = false;
  bool _needsStaleRefresh = false;
  bool _waitingForConnection = false;
  bool _wasPaused = false;
  bool _wasConnected = false;
  bool _stalePromptOptionsRefreshInFlight = false;

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
  /// [SessionDetailLoading]. Replayed once state becomes [SessionDetailLoaded];
  /// failed loads clear them.
  final List<SesoriSessionEvent> _pendingSessionEvents = [];

  /// Pending global SSE events that arrived while the cubit was in
  /// [SessionDetailLoading]. Replayed once state becomes [SessionDetailLoaded];
  /// failed loads clear them.
  final List<SseEvent> _pendingGlobalEvents = [];

  /// Fires the [SesoriQuestionAsked] whenever a new question arrives, so the
  /// screen can auto-open the question modal.
  final StreamController<SesoriQuestionAsked> _questionStream = StreamController.broadcast();
  Stream<SesoriQuestionAsked> get questionStream => _questionStream.stream;

  /// Fires the [SesoriPermissionAsked] whenever a new permission arrives, so the
  /// screen can auto-open the permission modal.
  final StreamController<SesoriPermissionAsked> _permissionStream = StreamController.broadcast();
  Stream<SesoriPermissionAsked> get permissionStream => _permissionStream.stream;

  final StreamController<SessionDetailNotice> _noticeStream = StreamController.broadcast();
  Stream<SessionDetailNotice> get noticeStream => _noticeStream.stream;

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  this : super(const SessionDetailState.loading()) {
    _streamingBuffer = StreamingTextBuffer(onFlush: _emitStreamingSnapshot);
    // Seed the connection state so the BehaviorSubject's immediate replay isn't
    // treated as a reconnect transition.
    _wasConnected = _connectionService.currentStatus is ConnectionConnected;
    _subscriptions
      ..add(_connectionService.sessionEvents(_sessionId).listen(_handleEvent))
      ..add(_connectionService.events.listen(_handleGlobalEvent))
      ..add(_connectionService.status.listen(_onConnectionStatusChanged))
      ..add(
        _connectionService.dataMayBeStale.listen(
          (_) => _onDataMayBeStale(trigger: _SessionRefreshTrigger.dataMayBeStale),
        ),
      )
      ..add(_lifecycleSource.lifecycleStateStream.listen(_onLifecycleChanged));
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
    final parkEpochAtFetch = _parkEpoch;
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
        emit(_buildLoadedState(snapshot: snapshot, parkEpochAtFetch: parkEpochAtFetch));
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
        awaitingBridgeSubmissions: _promptQueue.awaitingBridge,
        sendingSubmission: _promptQueue.active,
      ),
    );

    final parkEpochAtFetch = _parkEpoch;
    try {
      final result = await _loadService.reload(sessionId: _sessionId, projectId: _projectId);
      if (isClosed) return _SessionRefreshResult.closed;
      if (connectionGeneration != _connectionGeneration) {
        _emitRefreshEnded();
        return _SessionRefreshResult.staleConnection;
      }

      switch (result) {
        case SessionDetailLoadResultLoaded(:final snapshot):
          _waitingForConnection = false;
          final derived = _deriveSnapshot(snapshot);
          final latestAssistant = derived.latestAssistant;
          final availableAgents = derived.agents;
          final availableProviders = derived.providers;

          final streamingText = _streamingBuffer.snapshot();
          _streamingBuffer.clear();

          final refreshedChildSessions = derived.children;

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
          _reconcileStagedWithSnapshot(snapshot: snapshot, parkEpochAtFetch: parkEpochAtFetch);

          final refreshedSessionStatus = snapshot.statuses[_sessionId] ?? const SessionStatus.idle();
          final queue = _queueView(bridgePrompts: snapshot.bridgeQueuedPrompts);

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
              pendingQuestions: _mapPendingQuestions(snapshot.pendingQuestions),
              pendingPermissions: _mapPendingPermissions(snapshot.pendingPermissions),
              bridgeQueuedPrompts: snapshot.bridgeQueuedPrompts,
              agent: latestAssistant?.agent,
              assistantAgentModel: derived.assistantAgentModel,
              children: refreshedChildSessions,
              childStatuses: derived.childStatuses,
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
              queuedMessages: queue.queuedMessages,
              awaitingBridgeSubmissions: queue.awaitingBridgeSubmissions,
              sendingSubmission: queue.sendingSubmission,
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
          _emitRefreshEnded();
          return _SessionRefreshResult.waitingForConnection;
        case SessionDetailLoadResultFailed(:final error, :final stackTrace):
          logw("Silent refresh failed", error, stackTrace);
          _emitRefreshEnded();
          return _SessionRefreshResult.failed;
      }
    } on Object catch (error, stackTrace) {
      logw("Silent refresh failed", error, stackTrace);
      if (isClosed) return _SessionRefreshResult.closed;
      _emitRefreshEnded();
      return _SessionRefreshResult.failed;
    }
  }

  void _emitRefreshEnded() {
    final latest = state;
    if (latest is! SessionDetailLoaded) return;
    emit(
      latest.copyWith(
        isRefreshing: false,
        queuedMessages: _promptQueue.items,
        awaitingBridgeSubmissions: _promptQueue.awaitingBridge,
        sendingSubmission: _promptQueue.active,
      ),
    );
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

  /// Returns the latest agent-authored assistant or error [Message], or null if none.
  Message? _latestAssistantOrErrorMessage(List<MessageWithParts> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final info = messages[i].info;
      switch (info) {
        case MessageAssistant(sender: MessageSender.agent) || MessageError():
          return info;
        case MessageAssistant() || MessageUser():
          continue;
      }
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
            SesoriTodoUpdated() ||
            SesoriTuiToastShow():
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
            .catchError((Object error, StackTrace stackTrace) {
              logw("Failed to record session event handler failure", error, stackTrace);
            }),
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
            .catchError((Object error, StackTrace stackTrace) {
              logw("Failed to record global session event handler failure", error, stackTrace);
            }),
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
        persistedModel != null && _isModelAvailable(model: persistedModel, providers: providers);

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
  bool _surfacesChildRequestHere({required String sessionID, required String? displaySessionId}) {
    return sessionID != _sessionId && displaySessionId == _sessionId;
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

    if (message
        case MessageAssistant(sender: MessageSender.agent, :final providerID, :final modelID, :final agent) ||
            MessageError(:final providerID, :final modelID, :final agent)) {
      final assistantAgentModel = providerID != null && modelID != null
          ? _resolveAgentModel(
              agents: current.availableAgents,
              providerID: providerID,
              modelID: modelID,
            )
          : current.assistantAgentModel;
      emit(
        current.copyWith(
          messages: messages,
          agent: agent ?? current.agent,
          assistantAgentModel: assistantAgentModel,
        ),
      );
    } else {
      emit(current.copyWith(messages: messages));
    }
    _drainDeferredPartsForMessage(messageId: message.id);
    // A user envelope usually arrives before its first text part; releasing
    // the queued copies runs only once the message can actually render, so
    // the row never blanks between the envelope and that part.
    if (message is MessageUser) _releaseDeliveredPrompt(messageId: message.id);
  }

  /// Drops every queued copy of a delivered prompt — the bridge queue entry
  /// and any locally staged/parked duplicate of a send whose response was
  /// lost — once its user message is renderable. The transcript list keys
  /// all of them to one row id, so the swap is seamless whichever emission
  /// order the events arrive in.
  void _releaseDeliveredPrompt({required String messageId}) {
    if (isClosed) return;
    final current = state;
    if (current is! SessionDetailLoaded) return;
    final message = current.messages.where((item) => item.info.id == messageId).firstOrNull;
    if (message == null || !message.hasRenderableUserContent) return;
    final info = message.info;
    if (info is! MessageUser) return;
    final promptId = info.promptId;
    // Keyed by association, not just id: an upsert that later attaches a
    // prompt id must still reconcile, while repeated part updates of one
    // association stay idempotent.
    if (!_accountedUserMessages.add((messageId: messageId, promptId: promptId))) return;
    // Only identity settles a prompt. Content cannot: another surface's echo
    // may contain this text, identical prompts collide, and an attachment-only
    // echo carries none — and a wrong match would discard a send the user
    // still owns. Harness echoes reach the client with an id because each
    // plugin stamps the echo of its own dispatch; a harness that publishes no
    // user echo leaves the staged prompt to snapshot reconciliation.
    if (promptId == null) return;
    _promptQueue.removeByPromptId(promptId);
    final bridgePrompts = [
      for (final prompt in current.bridgeQueuedPrompts)
        if (prompt.id != promptId) prompt,
    ];
    final queue = _queueView(bridgePrompts: bridgePrompts);
    emit(
      current.copyWith(
        bridgeQueuedPrompts: bridgePrompts,
        queuedMessages: queue.queuedMessages,
        awaitingBridgeSubmissions: queue.awaitingBridgeSubmissions,
        sendingSubmission: queue.sendingSubmission,
      ),
    );
    // The delivered prompt's own send may have stopped the drain on a lost
    // response; anything staged behind it must not stay parked.
    _tryDrainQueue();
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
    final queue = _queueView(bridgePrompts: prompts);
    emit(
      current.copyWith(
        bridgeQueuedPrompts: prompts,
        queuedMessages: queue.queuedMessages,
        awaitingBridgeSubmissions: queue.awaitingBridgeSubmissions,
        sendingSubmission: queue.sendingSubmission,
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
    final queue = _queueView(bridgePrompts: bridgePrompts);
    emit(
      current.copyWith(
        bridgeQueuedPrompts: bridgePrompts,
        queuedMessages: queue.queuedMessages,
        awaitingBridgeSubmissions: queue.awaitingBridgeSubmissions,
        sendingSubmission: queue.sendingSubmission,
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
    if (current is! SessionDetailLoaded || isClosed) return;
    emit(current.copyWith(sessionStatus: status));
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
    // The part may be what makes a delivered user prompt renderable.
    if (message.info is MessageUser) _releaseDeliveredPrompt(messageId: part.messageID);
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
      _staleOptionsRecoveryAttemptedPromptIds.remove(removed.promptId);
      _emitQueueUpdate(current);
      _tryDrainQueue();
    }
  }

  /// Syncs queued prompt items into the cubit state.
  void _emitQueueUpdate([SessionDetailLoaded? known]) {
    if (isClosed) return;
    final current = known ?? state;
    if (current is! SessionDetailLoaded) return;
    final queue = _queueView(bridgePrompts: current.bridgeQueuedPrompts);
    emit(
      current.copyWith(
        queuedMessages: queue.queuedMessages,
        awaitingBridgeSubmissions: queue.awaitingBridgeSubmissions,
        sendingSubmission: queue.sendingSubmission,
      ),
    );
  }

  /// Drops staged copies a fresh snapshot proves the bridge already owns —
  /// listed in its queue or landed as a user message with the same prompt id.
  void _reconcileStagedWithSnapshot({required SessionDetailSnapshot snapshot, required int parkEpochAtFetch}) {
    final owned = <String>{};
    for (final prompt in snapshot.bridgeQueuedPrompts) {
      owned.add(prompt.id);
      _promptQueue.removeByPromptId(prompt.id);
    }
    for (final message in snapshot.messages) {
      if (message.info case MessageUser(promptId: final promptId?)) {
        // The snapshot holding the message at all proves the bridge owns the
        // prompt, so it must never be settled as absent — but a bare envelope
        // cannot render, and releasing the local copy on it would blank the
        // row until its first part arrives (same gate as the live path).
        owned.add(promptId);
        if (!message.hasRenderableUserContent) continue;
        _promptQueue.removeByPromptId(promptId);
      }
    }
    // A successful snapshot that holds neither the queue entry nor the
    // message for a prompt parked before its fetch began proves the bridge
    // no longer owns it — settle it instead of showing a ghost bubble
    // forever. Prompts parked after the fetch began are untouched.
    _promptQueue.settleAwaitingAbsent(ownedPromptIds: owned, parkedAtOrBeforeEpoch: parkEpochAtFetch);
  }

  /// Staged sends not yet owned by the bridge. A staged copy whose id the
  /// bridge queue already lists renders nowhere; its in-flight send settles
  /// (or its idempotent retry no-ops) without a second bubble.
  _QueueView _queueView({required List<QueuedSessionPrompt> bridgePrompts}) => (
    queuedMessages: _visibleStagedItems(bridgePrompts: bridgePrompts),
    awaitingBridgeSubmissions: _visibleAwaitingBridge(bridgePrompts: bridgePrompts),
    sendingSubmission: _visibleStagedSending(bridgePrompts: bridgePrompts),
  );

  List<QueuedSessionSubmission> _visibleStagedItems({required List<QueuedSessionPrompt> bridgePrompts}) {
    if (bridgePrompts.isEmpty) return _promptQueue.items;
    final bridgeIds = {for (final prompt in bridgePrompts) prompt.id};
    return [
      for (final item in _promptQueue.items)
        if (!bridgeIds.contains(item.promptId)) item,
    ];
  }

  /// Accepted-but-unlisted sends still owed a bridge representation. Hidden
  /// once the bridge queue lists their prompt id.
  List<QueuedSessionSubmission> _visibleAwaitingBridge({required List<QueuedSessionPrompt> bridgePrompts}) {
    final awaiting = _promptQueue.awaitingBridge;
    if (bridgePrompts.isEmpty || awaiting.isEmpty) return awaiting;
    final bridgeIds = {for (final prompt in bridgePrompts) prompt.id};
    return [
      for (final item in awaiting)
        if (!bridgeIds.contains(item.promptId)) item,
    ];
  }

  QueuedSessionSubmission? _visibleStagedSending({required List<QueuedSessionPrompt> bridgePrompts}) {
    final active = _promptQueue.active;
    if (active == null || _promptQueue.isActiveSettledElsewhere) return null;
    return bridgePrompts.any((prompt) => prompt.id == active.promptId) ? null : active;
  }

  Future<void> _drainQueuedMessages() async {
    if (_promptQueue.isSending || _stalePromptOptionsRefreshInFlight) return;
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
    var optionsRecovered = false;
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
          // Parked, not dropped: the bubble keeps rendering from the parked
          // slot until the bridge's queue statement, its delivered message, or
          // an authoritative refresh accounts for the prompt, so acceptance
          // outrunning those never blanks the row. A send whose echo already
          // landed was marked settled and is consumed here instead.
          _promptQueue.parkAccepted(epoch: ++_parkEpoch);
          _staleOptionsRecoveryAttemptedPromptIds.remove(submission.promptId);
          _reportAcceptedSubmission(submission: submission);
        case ErrorResponse(:final error) when SessionRepository.isStalePromptOptionsError(error: error):
          sendSettledElsewhere = !_promptQueue.failSend();
          if (!sendSettledElsewhere) {
            if (!_staleOptionsRecoveryAttemptedPromptIds.add(submission.promptId)) {
              if (!isClosed) _noticeStream.add(SessionDetailNotice.promptOptionsRecoveryFailed);
            } else {
              _stalePromptOptionsRefreshInFlight = true;
              try {
                optionsRecovered = await _refreshStalePromptOptions();
              } finally {
                _stalePromptOptionsRefreshInFlight = false;
              }
            }
          }
        case ErrorResponse(:final error):
          sendSettledElsewhere = !_promptQueue.failSend();
          logw("Failed to send queued session submission", error);
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
    if (optionsRecovered && _isConnected) {
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

  Future<bool> _refreshStalePromptOptions() async {
    final current = state;
    if (current is! SessionDetailLoaded) return false;
    final pluginId = current.pluginId;
    if (pluginId == null) {
      logw("Could not refresh stale prompt options because the session plugin is unresolved");
      if (!isClosed) _noticeStream.add(SessionDetailNotice.promptOptionsRecoveryFailed);
      return false;
    }

    try {
      final result = await _sessionRepository.loadSessionOptions(
        projectId: _projectId,
        pluginId: pluginId,
        mode: SessionOptionsRequestMode.forceRefresh,
      );
      if (isClosed) return false;
      final latest = state;
      if (latest is! SessionDetailLoaded) return false;

      if (result case SessionOptionsRepositoryAvailable(:final catalog)) {
        final agents = catalog.agents
            .whereType<AgentInfo>()
            .where((agent) => !agent.hidden && agent.mode != AgentMode.subagent)
            .toList();
        final providers = catalog.providers;
        final commands = catalog.commands;
        final selectedAgent = agents.any((agent) => agent.name == latest.selectedAgent)
            ? latest.selectedAgent
            : (agents.firstOrNull?.name ?? "build");
        final agentChanged = selectedAgent != latest.selectedAgent;
        final preferredAgentModel = agents.firstWhereOrNull((agent) => agent.name == selectedAgent)?.model;
        final selectedModelCandidate = agentChanged && preferredAgentModel != null
            ? preferredAgentModel
            : latest.selectedAgentModel;
        final selectedModel = _validatedPromptModel(
          candidate: selectedModelCandidate,
          agents: agents,
          providers: providers,
        );

        _promptQueue.replacePending(
          update: (submission) => submission.withSelection(
            agent: _validatedQueuedAgent(candidate: submission.agent, agents: agents),
            agentModel: submission.agentModel == null
                ? null
                : _validatedPromptModel(
                    candidate: submission.agentModel,
                    agents: agents,
                    providers: providers,
                  ),
          ),
        );

        emit(
          latest.copyWith(
            availableAgents: agents,
            availableProviders: providers,
            availableCommands: commands,
            selectedAgent: selectedAgent,
            selectedAgentModel: selectedModel,
            availableVariants: _deriveAvailableVariants(
              providers: providers,
              model: selectedModel,
            ),
            stagedCommand: _resolveStagedCommand(
              availableCommands: commands,
              stagedCommand: latest.stagedCommand,
            ),
            queuedMessages: _visibleStagedItems(bridgePrompts: latest.bridgeQueuedPrompts),
            sendingSubmission: _visibleStagedSending(bridgePrompts: latest.bridgeQueuedPrompts),
          ),
        );
        _noticeStream.add(SessionDetailNotice.promptOptionsUpdated);
        return true;
      }

      final error = switch (result) {
        SessionOptionsRepositoryAvailable() => null,
        SessionOptionsRepositoryCacheUnavailable() => null,
        SessionOptionsRepositoryUnsupported() => null,
        SessionOptionsRepositoryProjectNotFound(:final error) => error,
        SessionOptionsRepositoryRefreshFailedRetained() => null,
        SessionOptionsRepositoryRefreshFailedUnavailable() => null,
        SessionOptionsRepositoryFailure(:final error) => error,
      };
      if (error == null) {
        logw("Failed to refresh stale prompt options (${result.runtimeType.toString()})");
      } else {
        logw("Failed to refresh stale prompt options", error);
      }
      _noticeStream.add(SessionDetailNotice.promptOptionsRecoveryFailed);
      return false;
    } on Object catch (error, stackTrace) {
      logw("Failed to refresh stale prompt options", error, stackTrace);
      if (!isClosed) _noticeStream.add(SessionDetailNotice.promptOptionsRecoveryFailed);
      return false;
    }
  }

  String? _validatedQueuedAgent({
    required String? candidate,
    required List<AgentInfo> agents,
  }) {
    if (candidate == null || agents.any((agent) => agent.name == candidate)) return candidate;
    return agents.firstOrNull?.name;
  }

  AgentModel? _validatedPromptModel({
    required AgentModel? candidate,
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
  }) {
    if (candidate == null) return null;
    final model = _isModelAvailable(model: candidate, providers: providers)
        ? candidate
        : _fallbackAgentModel(agents: agents, providers: providers);
    if (model == null) return null;
    // Never leave a variant-offering model unset: the composer renders the
    // first available variant when none is selected, so an unset one would
    // display an effort the send does not carry.
    return _withResolvedVariant(
      model: model,
      availableVariants: _deriveAvailableVariants(providers: providers, model: model),
    );
  }

  bool _isModelAvailable({required AgentModel model, required List<ProviderInfo> providers}) {
    return providers.any(
      (provider) => provider.id == model.providerID && provider.models.containsKey(model.modelID),
    );
  }

  AgentModel? _fallbackAgentModel({
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
  }) {
    if (agents.firstOrNull?.model case final model?) return model;
    // Walk every provider: the first may be misconfigured or fully
    // deprecated and therefore have no selectable model.
    for (final provider in providers) {
      final picked = _defaultModelSelector.pickFromProvider(
        models: provider.models,
        defaultModelID: provider.defaultModelID,
      );
      if (picked != null) {
        return AgentModel(
          providerID: provider.id,
          modelID: picked.id,
          variant: null,
        );
      }
    }
    return null;
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
    _notificationCanceller?.cancelForSession(sessionId: _sessionId);
  }

  /// Restores this loaded session as the active view after a pushed child route
  /// is removed. The initial load and refresh paths own their own declarations;
  /// an unloaded or failed route must not mark the session seen.
  void reassertViewingSession() {
    if (state is SessionDetailLoaded) _sessionViewingService.setViewingSession(_sessionId);
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
  }) => _submitReply(
    requestId: requestId,
    sessionId: sessionId,
    archivedAction: "reply to a question",
    failureAction: "reply to question",
    resolve: _onQuestionResolved,
    submit: () => _sessionRepository.replyToQuestion(requestId: requestId, sessionId: sessionId, answers: answers),
    reportSuccess: () => _reportProductEvent(event: const ProductAnalyticsEvent.sessionQuestionAnswered()),
  );

  Future<bool> rejectQuestion(String requestId) async {
    if (_refuseWhenArchived(action: "reject a question")) return false;

    // Reject against the question's owning session (which may be a child/
    // sub-agent surfaced on this root), mirroring the reply path, so the bridge
    // clears its tracker under the correct session instead of the open root.
    final current = state;
    final ownerSessionId = current is SessionDetailLoaded
        ? (current.pendingQuestions.firstWhereOrNull((q) => q.id == requestId)?.sessionID ?? _sessionId)
        : _sessionId;
    return await _submitReply(
      requestId: requestId,
      sessionId: _sessionId,
      archivedAction: "reject a question",
      failureAction: "reject question",
      resolve: _onQuestionResolved,
      submit: () => _sessionRepository.rejectQuestion(requestId: requestId, sessionId: ownerSessionId),
      reportSuccess: () => _reportProductEvent(event: const ProductAnalyticsEvent.sessionQuestionRejected()),
      checkArchived: false,
    );
  }

  Future<bool> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) => _submitReply(
    requestId: requestId,
    sessionId: sessionId,
    archivedAction: "reply to a permission",
    failureAction: "reply to permission",
    resolve: _onPermissionResolved,
    submit: () => _permissionRepository.replyToPermission(requestId: requestId, sessionId: sessionId, reply: reply),
    reportSuccess: () => _reportProductEvent(
      event: ProductAnalyticsEvent.sessionPermissionAnswered(decision: _analyticsPermissionDecision(reply: reply)),
    ),
  );

  Future<bool> _submitReply({
    required String requestId,
    required String sessionId,
    required String archivedAction,
    required String failureAction,
    required void Function(String requestId) resolve,
    required Future<ApiResponse<void>> Function() submit,
    required void Function() reportSuccess,
    bool checkArchived = true,
  }) async {
    if (checkArchived && _refuseWhenArchived(action: archivedAction)) return false;
    resolve(requestId);
    _notificationCanceller?.cancelForSession(sessionId: sessionId);
    try {
      final result = await submit();
      if (result case ErrorResponse(:final error)) throw error;
      reportSuccess();
      return true;
    } on Object catch (error, stackTrace) {
      loge("Failed to $failureAction $requestId", error, stackTrace);
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
    final availableVariants = _deriveAvailableVariants(
      providers: current.availableProviders,
      model: agentModel,
    );

    if (isClosed) return;
    emit(
      current.copyWith(
        selectedAgent: agent,
        selectedAgentModel: _withResolvedVariant(model: agentModel, availableVariants: availableVariants),
        availableVariants: availableVariants,
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
    final variant = availableVariants.any((v) => v.id == previousVariant)
        ? previousVariant
        : availableVariants.firstOrNull?.id;

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

  void selectVariant(SessionVariant variant) {
    final current = state;
    if (current is! SessionDetailLoaded) return;
    final agentModel = current.selectedAgentModel;
    if (agentModel == null) return;

    if (isClosed) return;
    emit(current.copyWith(selectedAgentModel: agentModel.copyWith(variant: variant.id)));
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

  /// Stops the session with the given sub-agent scope.
  ///
  /// `confirm` is a side-effect-free probe: nothing local changes until the
  /// bridge accepts. On acceptance the local prompt queue is cleared (stop
  /// means "run nothing further"; the bridge clears its own queue), and under
  /// `stop` every busy child session is aborted too — plugins whose children
  /// are real sessions keep today's stop-everything behavior.
  Future<SessionAbortOutcome> abort({required SessionAbortSubAgentPolicy subAgents}) async {
    try {
      final current = state;
      final root = await _sessionRepository.abortSession(sessionId: _sessionId, subAgents: subAgents);
      if (root case ErrorResponse(:final error)) throw error;

      if (_promptQueue.isNotEmpty || _promptQueue.isSending || _promptQueue.awaitingBridge.isNotEmpty) {
        _promptQueue.clear();
        _staleOptionsRecoveryAttemptedPromptIds.clear();
        _emitQueueUpdate(current is SessionDetailLoaded ? current : null);
      }
      if (subAgents != SessionAbortSubAgentPolicy.keep && current is SessionDetailLoaded) {
        final results = await Future.wait([
          for (final MapEntry(key: childId, value: status) in current.childStatuses.entries)
            if (status is SessionStatusBusy || status is SessionStatusRetry)
              _sessionRepository.abortSession(sessionId: childId, subAgents: SessionAbortSubAgentPolicy.stop),
        ]);
        for (final result in results) {
          if (result case ErrorResponse(:final error)) throw error;
        }
      }
      _reportProductEvent(event: const ProductAnalyticsEvent.sessionAbortSucceeded());
      return const SessionAbortOutcome.aborted();
    } on SessionAbortApiRejectedException catch (e) {
      return SessionAbortOutcome.rejected(rejection: e.rejection);
    } on Object catch (e, st) {
      loge("Failed to abort session(s)", e, st);
      return const SessionAbortOutcome.aborted();
    }
  }

  _SnapshotDerivation _deriveSnapshot(SessionDetailSnapshot snapshot) {
    final latestAssistant = _latestAssistantOrErrorMessage(snapshot.messages);
    final children = [...snapshot.childSessions];
    _sortChildrenByUpdatedDesc(children);
    final childIds = children.map((child) => child.id).toSet();
    final agents = snapshot.agents.where((agent) => !agent.hidden && agent.mode != AgentMode.subagent).toList();
    final assistantAgentModel = switch (latestAssistant) {
      MessageAssistant(sender: MessageSender.agent, :final modelID, :final providerID) ||
      MessageError(
        :final modelID,
        :final providerID,
      ) => _resolveAgentModel(agents: agents, providerID: providerID, modelID: modelID),
      MessageAssistant() || MessageUser() || null => null,
    };
    return (
      latestAssistant: latestAssistant,
      assistantAgentModel: assistantAgentModel,
      children: children,
      childStatuses: Map.fromEntries(snapshot.statuses.entries.where((entry) => childIds.contains(entry.key))),
      agents: agents,
      providers: snapshot.providerData?.items ?? <ProviderInfo>[],
    );
  }

  SessionDetailLoaded _buildLoadedState({required SessionDetailSnapshot snapshot, required int parkEpochAtFetch}) {
    _reconcileStagedWithSnapshot(snapshot: snapshot, parkEpochAtFetch: parkEpochAtFetch);
    final derived = _deriveSnapshot(snapshot);
    final latestAssistant = derived.latestAssistant;
    final childSessions = derived.children;
    final agents = derived.agents;
    final providers = derived.providers;

    final persistedDefaults = snapshot.promptDefaults;
    final persistedAgent = persistedDefaults?.agent;
    final persistedModel = persistedDefaults?.model;

    final bool hasValidPersistedAgent = persistedAgent != null && agents.any((a) => a.name == persistedAgent);
    final bool hasValidPersistedModel =
        persistedModel != null && _isModelAvailable(model: persistedModel, providers: providers);

    final String defaultAgent = hasValidPersistedAgent
        ? persistedAgent
        : (agents.isNotEmpty ? agents.first.name : "build");

    final assistantAgentModel = derived.assistantAgentModel;
    final defaultAgentModel = hasValidPersistedModel
        ? persistedModel
        : (assistantAgentModel ?? _fallbackAgentModel(agents: agents, providers: providers));

    final availableVariants = _deriveAvailableVariants(
      providers: providers,
      model: defaultAgentModel,
    );

    final initialSessionStatus = snapshot.statuses[_sessionId] ?? const SessionStatus.idle();
    final queue = _queueView(bridgePrompts: snapshot.bridgeQueuedPrompts);

    _transcriptGeneration++;
    return SessionDetailLoaded(
      messages: snapshot.messages,
      olderMessagesCursor: snapshot.olderMessagesCursor,
      streamingText: const {},
      sessionStatus: initialSessionStatus,
      pendingQuestions: _mapPendingQuestions(snapshot.pendingQuestions),
      pendingPermissions: _mapPendingPermissions(snapshot.pendingPermissions),
      bridgeQueuedPrompts: snapshot.bridgeQueuedPrompts,
      sessionTitle: snapshot.canonicalSessionTitle,
      pluginId: snapshot.pluginId,
      supportsPromptAttachments: snapshot.supportsPromptAttachments,
      agent: latestAssistant?.agent,
      assistantAgentModel: assistantAgentModel,
      children: childSessions,
      childStatuses: derived.childStatuses,
      isRootSession: snapshot.isRootSession,
      isArchived: snapshot.isArchived,
      queuedMessages: queue.queuedMessages,
      awaitingBridgeSubmissions: queue.awaitingBridgeSubmissions,
      sendingSubmission: queue.sendingSubmission,
      availableAgents: agents,
      availableProviders: providers,
      availableCommands: snapshot.commands,
      selectedAgent: defaultAgent,
      selectedAgentModel: _withResolvedVariant(
        model: defaultAgentModel,
        availableVariants: availableVariants,
      ),
      stagedCommand: null,
      isRefreshing: false,
      availableVariants: availableVariants,
    );
  }

  /// A model that offers variants always runs at a named one. An unset variant
  /// resolves to the first available, which plugins declare default-first.
  AgentModel? _withResolvedVariant({
    required AgentModel? model,
    required List<SessionVariant> availableVariants,
  }) {
    if (model == null) return null;
    if (availableVariants.any((variant) => variant.id == model.variant)) return model;
    return model.copyWith(variant: availableVariants.firstOrNull?.id);
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
    _subscriptions.dispose();
    _eventRefreshCooldown?.cancel();
    _streamingBuffer.dispose();
    _questionStream.close();
    _permissionStream.close();
    _noticeStream.close();
    return super.close();
  }
}

typedef _QueueView = ({
  List<QueuedSessionSubmission> queuedMessages,
  List<QueuedSessionSubmission> awaitingBridgeSubmissions,
  QueuedSessionSubmission? sendingSubmission,
});

typedef _SnapshotDerivation = ({
  Message? latestAssistant,
  AgentModel? assistantAgentModel,
  List<Session> children,
  Map<String, SessionStatus> childStatuses,
  List<AgentInfo> agents,
  List<ProviderInfo> providers,
});

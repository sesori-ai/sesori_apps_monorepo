import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../logging/logging.dart";
import "../../platform/notification_canceller.dart";
import "../../repositories/permission_repository.dart";
import "../../repositories/session_repository.dart";
import "../../services/session_detail_load_service.dart";
import "prompt_send_queue.dart";
import "queued_session_submission.dart";
import "session_detail_state.dart";
import "streaming_text_buffer.dart";

class SessionDetailCubit extends Cubit<SessionDetailState> {
  final SessionDetailLoadService _loadService;
  final SessionRepository _sessionRepository;
  final ConnectionService _connectionService;
  final PermissionRepository _permissionRepository;
  final String _sessionId;
  final String? _routeProjectId;
  final NotificationCanceller _notificationCanceller;
  final FailureReporter _failureReporter;
  final PromptSendQueue _promptQueue = PromptSendQueue();
  bool _isSending = false;

  late final StreamSubscription<SesoriSessionEvent> _eventSubscription;
  late final StreamSubscription<SseEvent> _globalEventSubscription;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late final StreamSubscription<void> _staleSubscription;
  late final StreamingTextBuffer _streamingBuffer;
  Future<void>? _activeRefresh;
  bool _needsStaleRefresh = false;
  bool _waitingForConnection = false;
  String? _projectId;

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
    required String sessionId,
    String? projectId,
    required NotificationCanceller notificationCanceller,
    required FailureReporter failureReporter,
  }) : _loadService = loadService,
        _sessionRepository = promptDispatcher,
        _connectionService = connectionService,
        _permissionRepository = permissionRepository,
        _sessionId = sessionId,
        _routeProjectId = projectId,
        _notificationCanceller = notificationCanceller,
        _failureReporter = failureReporter,
        _projectId = projectId,
        super(const SessionDetailState.loading()) {
    _streamingBuffer = StreamingTextBuffer(onFlush: _emitStreamingSnapshot);
    _eventSubscription = _connectionService.sessionEvents(_sessionId).listen(_handleEvent);
    _globalEventSubscription = _connectionService.events.listen(_handleGlobalEvent);
    _connectionStatusSubscription = _connectionService.status.listen(_onConnectionStatusChanged);
    _staleSubscription = _connectionService.dataMayBeStale.listen((_) => _onDataMayBeStale());
    _loadMessages(isReload: false);
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadMessages({required bool isReload}) async {
    emit(const SessionDetailState.loading());
    final result = isReload
        ? await _loadService.reload(sessionId: _sessionId, projectId: _projectId ?? _routeProjectId)
        : await _loadService.load(sessionId: _sessionId, projectId: _projectId ?? _routeProjectId);
    if (isClosed) return;

    switch (result) {
      case SessionDetailLoadResultLoaded(:final snapshot):
        _waitingForConnection = false;
        _projectId = snapshot.projectId;
        emit(_buildLoadedState(snapshot: snapshot));
        _tryDrainQueue();
      case SessionDetailLoadResultWaitingForConnection():
        _waitingForConnection = true;
        if (_connectionService.currentStatus is ConnectionConnected) {
          _waitingForConnection = false;
          unawaited(_loadMessages(isReload: true));
        }
      case SessionDetailLoadResultFailed(:final error):
        _waitingForConnection = false;
        emit(SessionDetailState.failed(error: error is ApiError ? error : ApiError.generic()));
    }
  }

  Future<void> reload() => _loadMessages(isReload: true);

  void _silentRefresh() {
    if (state is! SessionDetailLoaded) return;
    _activeRefresh ??= _doSilentRefresh().whenComplete(() => _activeRefresh = null);
  }

  Future<void> _doSilentRefresh() async {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    final preservedSelectedAgent = current.selectedAgent;
    final preservedSelectedProviderID = current.selectedProviderID;
    final preservedSelectedModelID = current.selectedModelID;
    final preservedStagedCommand = current.stagedCommand;

    emit(current.copyWith(isRefreshing: true));

    try {
      final result = await _loadService.reload(sessionId: _sessionId, projectId: _projectId ?? _routeProjectId);
      if (isClosed) return;

      switch (result) {
        case SessionDetailLoadResultLoaded(:final snapshot):
          _waitingForConnection = false;
          _projectId = snapshot.projectId ?? _projectId;
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

          emit(
            current.copyWith(
              messages: snapshot.messages,
              streamingText: streamingText,
              sessionStatus: snapshot.statuses[_sessionId] ?? const SessionStatus.idle(),
              pendingQuestions: _mapPendingQuestions(snapshot.pendingQuestions),
              pendingPermissions: current.pendingPermissions,
              agent: latestAssistant?.agent,
              modelID: latestAssistant?.modelID,
              providerID: latestAssistant?.providerID,
              children: snapshot.childSessions,
              childStatuses: childStatuses,
              availableAgents: availableAgents,
              availableProviders: availableProviders,
              availableCommands: snapshot.commands,
              sessionTitle: snapshot.canonicalSessionTitle ?? current.sessionTitle,
              selectedAgent: preservedSelectedAgent,
              selectedProviderID: preservedSelectedProviderID,
              selectedModelID: preservedSelectedModelID,
              stagedCommand: _resolveStagedCommand(
                availableCommands: snapshot.commands,
                stagedCommand: preservedStagedCommand,
              ),
              isRefreshing: false,
            ),
          );
        case SessionDetailLoadResultWaitingForConnection():
          _waitingForConnection = true;
          emit(current.copyWith(isRefreshing: false));
        case SessionDetailLoadResultFailed(:final error):
          logw("Silent refresh failed: ${error.toString()}");
          emit(current.copyWith(isRefreshing: false));
      }
    } catch (error) {
      logw("Silent refresh failed: ${error.toString()}");
      if (isClosed) return;
      emit(current.copyWith(isRefreshing: false));
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
      if (messages[i].info.role == "assistant") return messages[i].info;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // SSE event processing
  // ---------------------------------------------------------------------------

  void _handleEvent(SesoriSessionEvent event) {
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
        case SesoriSessionUpdated(:final info):
          _onSessionUpdated(info);
        case SesoriCommandExecuted():
          _onDataMayBeStale();
        case SesoriSessionError(:final error):
          if (error != null) {
            _onSessionError(error);
          }
        case SesoriSessionCreated() ||
            SesoriSessionDeleted() ||
            SesoriSessionDiff() ||
            SesoriSessionCompacted() ||
            // ignore: deprecated_member_use, legacy idle event is still emitted for backward compatibility
            SesoriSessionIdle() ||
            SesoriPermissionReplied() ||
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
    final data = event.data;
    try {
      switch (data) {
        case SesoriSessionCreated(:final info) when info.parentID == _sessionId:
          _onChildSessionCreated(info);
        case SesoriSessionStatus(:final sessionID, :final status):
          _onChildSessionStatus(sessionId: sessionID, status: status);
        case SesoriSessionUpdated(:final info):
          _onChildSessionUpdated(info);
        case SesoriSessionCreated() ||
            SesoriSessionDeleted() ||
            SesoriSessionDiff() ||
            SesoriSessionError() ||
            SesoriSessionCompacted() ||
            SesoriServerConnected() ||
            SesoriServerHeartbeat() ||
            SesoriServerInstanceDisposed() ||
            SesoriGlobalDisposed() ||
            // ignore: deprecated_member_use, legacy idle event is still emitted for backward compatibility
            SesoriSessionIdle() ||
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
            SesoriWorktreeFailed():
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

  void _onSessionUpdated(Session session) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    if (isClosed) return;
    emit(current.copyWith(sessionTitle: session.title));
  }

  void _onSessionError(SessionError error) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    if (isClosed) return;
    emit(current.copyWith(sessionErrors: [...current.sessionErrors, error]));
  }

  void _onChildSessionCreated(Session child) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    // Avoid duplicates.
    if (current.children.any((c) => c.id == child.id)) return;

    if (isClosed) return;
    final updated = [...current.children, child]
      ..sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));
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
    final updatedChildren = List<Session>.of(current.children);
    updatedChildren[index] = updatedChild;
    emit(current.copyWith(children: updatedChildren));
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

    if (message.role == "assistant") {
      emit(
        current.copyWith(
          messages: messages,
          agent: message.agent ?? current.agent,
          modelID: message.modelID ?? current.modelID,
          providerID: message.providerID ?? current.providerID,
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

  void _onConnectionStatusChanged(ConnectionStatus status) {
    if (isClosed) return;
    if (status is ConnectionConnected) {
      if (_waitingForConnection) {
        _waitingForConnection = false;
        unawaited(_loadMessages(isReload: true));
        return;
      }
      _tryDrainQueue();
      if (_needsStaleRefresh) {
        _needsStaleRefresh = false;
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
    final normalizedCommand = _normalizeOptionalText(command);
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
      model: _resolvePromptModel(
        providerID: current.selectedProviderID,
        modelID: current.selectedModelID,
      ),
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
        model: _resolvePromptModel(
          providerID: current.selectedProviderID,
          modelID: current.selectedModelID,
        ),
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

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  PromptModel? _resolvePromptModel({required String? providerID, required String? modelID}) {
    final normalizedProviderID = _normalizeOptionalText(providerID);
    final normalizedModelID = _normalizeOptionalText(modelID);
    if (normalizedProviderID == null || normalizedModelID == null) return null;
    return PromptModel(providerID: normalizedProviderID, modelID: normalizedModelID);
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
    for (final category in NotificationCategory.values) {
      if (category == NotificationCategory.unknown) continue;
      _notificationCanceller.cancelForSession(
        sessionId: _sessionId,
        category: category,
      );
    }
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
    _notificationCanceller.cancelForSession(
      sessionId: sessionId,
      category: NotificationCategory.aiInteraction,
    );
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
    _onQuestionResolved(requestId);
    _notificationCanceller.cancelForSession(
      sessionId: _sessionId,
      category: NotificationCategory.aiInteraction,
    );
    try {
      final result = await _sessionRepository.rejectQuestion(requestId: requestId);
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
    _notificationCanceller.cancelForSession(
      sessionId: sessionId,
      category: NotificationCategory.aiInteraction,
    );
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

    if (isClosed) return;
    emit(current.copyWith(selectedAgent: agent));
  }

  void selectModel({required String providerID, required String modelID}) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    if (isClosed) return;
    emit(current.copyWith(selectedProviderID: providerID, selectedModelID: modelID));
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
    final childSessions = [...snapshot.childSessions]
      ..sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));
    final childIds = childSessions.map((c) => c.id).toSet();
    final childStatuses = Map<String, SessionStatus>.fromEntries(
      snapshot.statuses.entries.where((e) => childIds.contains(e.key)),
    );
    final agents = snapshot.agents
        .whereType<AgentInfo>()
        .where((a) => !a.hidden && a.mode != AgentMode.subagent)
        .toList();
    final providers = snapshot.providerData?.items ?? <ProviderInfo>[];
    final defaultAgent = agents.isNotEmpty ? agents.first.name : "build";
    final agentModel = agents.isNotEmpty ? agents.first.model : null;
    final String defaultProviderID;
    final String defaultModelID;
    if (agentModel != null) {
      defaultProviderID = agentModel.providerID;
      defaultModelID = agentModel.modelID;
    } else if (providers.isNotEmpty) {
      defaultProviderID = providers.first.id;
      final firstProviderDefaultModelId = providers.first.defaultModelID;
      defaultModelID =
          firstProviderDefaultModelId != null && providers.first.models.containsKey(firstProviderDefaultModelId)
          ? firstProviderDefaultModelId
          : providers.first.models.values.first.id;
    } else {
      defaultProviderID = "";
      defaultModelID = "";
    }

    return SessionDetailState.loaded(
          messages: snapshot.messages,
          sessionErrors: const [],
          streamingText: const {},
          sessionStatus: snapshot.statuses[_sessionId] ?? const SessionStatus.idle(),
          pendingQuestions: _mapPendingQuestions(snapshot.pendingQuestions),
          pendingPermissions: const [],
          sessionTitle: snapshot.canonicalSessionTitle,
          agent: latestAssistant?.agent,
          modelID: latestAssistant?.modelID,
          providerID: latestAssistant?.providerID,
          children: childSessions,
          childStatuses: childStatuses,
          queuedMessages: const [],
          availableAgents: agents,
          availableProviders: providers,
          availableCommands: snapshot.commands,
          selectedAgent: defaultAgent,
          selectedProviderID: defaultProviderID,
          selectedModelID: defaultModelID,
          stagedCommand: null,
          isRefreshing: false,
        )
        as SessionDetailLoaded;
  }

  List<SesoriQuestionAsked> _mapPendingQuestions(List<PendingQuestion> pendingQuestions) {
    return pendingQuestions
        .where((q) => q.sessionID == _sessionId)
        .map(
          (q) => SesoriQuestionAsked(
            id: q.id,
            sessionID: q.sessionID,
            questions: q.questions,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() {
    _eventSubscription.cancel();
    _globalEventSubscription.cancel();
    _connectionStatusSubscription.cancel();
    _staleSubscription.cancel();
    _streamingBuffer.dispose();
    _questionStream.close();
    _permissionStream.close();
    return super.close();
  }
}

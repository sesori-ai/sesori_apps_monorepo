import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../capabilities/session/session_service.dart";
import "../../logging/logging.dart";
import "../../platform/notification_canceller.dart";
import "../../repositories/permission_repository.dart";
import "prompt_send_service.dart";
import "session_detail_state.dart";
import "streaming_text_buffer.dart";

class SessionDetailCubit extends Cubit<SessionDetailState> {
  final SessionService _service;
  final ConnectionService _connectionService;
  final PermissionRepository _permissionRepository;
  final String _sessionId;
  final String? _projectId;
  final NotificationCanceller _notificationCanceller;
  final FailureReporter _failureReporter;
  late final PromptSendService _sendService;

  late final StreamSubscription<SesoriSessionEvent> _eventSubscription;
  late final StreamSubscription<SseEvent> _globalEventSubscription;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late final StreamSubscription<void> _staleSubscription;
  late final StreamingTextBuffer _streamingBuffer;
  Future<void>? _activeRefresh;
  bool _needsStaleRefresh = false;

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
    SessionService service,
    ConnectionService connectionService, {
    required PermissionRepository permissionRepository,
    required String sessionId,
    required String? projectId,
    required NotificationCanceller notificationCanceller,
    required FailureReporter failureReporter,
  }) : _service = service,
       _connectionService = connectionService,
       _permissionRepository = permissionRepository,
       _sessionId = sessionId,
       _projectId = projectId,
       _notificationCanceller = notificationCanceller,
       _failureReporter = failureReporter,
       super(const SessionDetailState.loading()) {
    _sendService = PromptSendService(
      service: _service,
      sessionId: _sessionId,
      onQueueChanged: _emitQueueUpdate,
      stateProvider: () {
        final current = state;
        return (
          agent: current is SessionDetailLoaded ? current.selectedAgent : null,
          providerID: current is SessionDetailLoaded ? current.selectedProviderID : null,
          modelID: current is SessionDetailLoaded ? current.selectedModelID : null,
          isConnected: _isConnected,
          isLoaded: current is SessionDetailLoaded && !isClosed,
        );
      },
    );
    _streamingBuffer = StreamingTextBuffer(onFlush: _emitStreamingSnapshot);
    _eventSubscription = _connectionService.sessionEvents(_sessionId).listen(_handleEvent);
    _globalEventSubscription = _connectionService.events.listen(_handleGlobalEvent);
    _connectionStatusSubscription = _connectionService.status.listen(_onConnectionStatusChanged);
    _staleSubscription = _connectionService.dataMayBeStale.listen((_) => _onDataMayBeStale());
    _loadMessages();
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> _loadMessages() async {
    emit(const SessionDetailState.loading());
    try {
      final snapshot = await _fetchSessionSnapshot();
      if (isClosed) return;

      final latestAssistant = _latestAssistantMessage(snapshot.messages);
      final childSessions = [...snapshot.childSessions]
        ..sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));

      // Filter statuses to only include child session IDs.
      final childIds = childSessions.map((c) => c.id).toSet();
      final childStatuses = Map<String, SessionStatus>.fromEntries(
        snapshot.statuses.entries.where((e) => childIds.contains(e.key)),
      );

      // Filter agents: only show visible, non-subagent agents for user selection.
      final agents = snapshot.agents
          .whereType<AgentInfo>()
          .where((a) => !a.hidden && a.mode != AgentMode.subagent)
          .toList();

      // Only connected providers with active models.
      final providers = snapshot.providerData?.items ?? <ProviderInfo>[];

      // Resolve default agent: first in list (server sorts default first).
      final defaultAgent = agents.isNotEmpty ? agents.first.name : "build";

      // Resolve default model:
      // 1. If the default agent has an explicit model preference, use it.
      // 2. Otherwise, pick the first connected provider's default model.
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

      emit(
        SessionDetailState.loaded(
          messages: snapshot.messages,
          streamingText: const {},
          sessionStatus: snapshot.statuses[_sessionId] ?? const SessionStatus.idle(),
          pendingQuestions: snapshot.pendingQuestions
              .where((q) => q.sessionID == _sessionId)
              .map(
                (q) => SesoriQuestionAsked(
                  id: q.id,
                  sessionID: q.sessionID,
                  questions: q.questions,
                ),
              )
              .toList(),
          pendingPermissions: const [],
          sessionTitle: null,
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
        ),
      );

      // Drain any messages that were queued before load completed.
      _tryDrainQueue();
    } catch (error) {
      if (isClosed) return;
      emit(SessionDetailState.failed(error: error is ApiError ? error : ApiError.generic()));
    }
  }

  Future<void> reload() => _loadMessages();

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
      final snapshot = await _fetchSessionSnapshot();
      if (isClosed) return;

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
          pendingQuestions: snapshot.pendingQuestions
              .where((q) => q.sessionID == _sessionId)
              .map(
                (q) => SesoriQuestionAsked(
                  id: q.id,
                  sessionID: q.sessionID,
                  questions: q.questions,
                ),
              )
              .toList(),
          pendingPermissions: current.pendingPermissions,
          agent: latestAssistant?.agent,
          modelID: latestAssistant?.modelID,
          providerID: latestAssistant?.providerID,
          children: snapshot.childSessions,
          childStatuses: childStatuses,
          availableAgents: availableAgents,
          availableProviders: availableProviders,
          availableCommands: snapshot.commands,
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
    } catch (error) {
      logw("Silent refresh failed: ${error.toString()}");
      if (isClosed) return;
      emit(current.copyWith(isRefreshing: false));
    }
  }

  /// Fetches a complete snapshot of session data from the API.
  /// Messages are required (throws on error). All other fields fall back to defaults.
  Future<
    ({
      List<MessageWithParts> messages,
      List<PendingQuestion> pendingQuestions,
      List<Session> childSessions,
      Map<String, SessionStatus> statuses,
      List<AgentInfo?> agents,
      ProviderListResponse? providerData,
      List<CommandInfo> commands,
    })
  >
  _fetchSessionSnapshot() async {
    final (
      messagesResponse,
      questionsResponse,
      childrenResponse,
      statusesResponse,
      agentsResponse,
      providersResponse,
      commandsResponse,
    ) = await (
      _service.getMessages(_sessionId),
      _service.getPendingQuestions(_sessionId),
      _service.getChildren(_sessionId),
      _service.getSessionStatuses(),
      _service.listAgents(),
      _service.listProviders(),
      _service.listCommands(projectId: _projectId ?? ""),
    ).wait;

    final messages = switch (messagesResponse) {
      SuccessResponse(:final data) => data.messages,
      ErrorResponse(:final error) => throw error,
    };

    final pendingQuestions = switch (questionsResponse) {
      SuccessResponse(:final data) => data.data,
      ErrorResponse() => <PendingQuestion>[],
    };
    final childSessions = switch (childrenResponse) {
      SuccessResponse(:final data) => data.items,
      ErrorResponse() => <Session>[],
    };
    final statuses = switch (statusesResponse) {
      SuccessResponse(:final data) => data.statuses,
      ErrorResponse() => <String, SessionStatus>{},
    };
    final agents = switch (agentsResponse) {
      SuccessResponse(:final data) => data.agents,
      ErrorResponse(:final error) => () {
        loge("Failed to load agents: ${error.toString()}");
        return <AgentInfo>[];
      }(),
    };
    final providerData = switch (providersResponse) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => () {
        loge("Failed to load providers: ${error.toString()}");
        return null;
      }(),
    };
    final commands = switch (commandsResponse) {
      SuccessResponse(:final data) => data.items,
      ErrorResponse(:final error) => () {
        loge("Failed to load commands: ${error.toString()}");
        return <CommandInfo>[];
      }(),
    };

    return (
      messages: messages,
      pendingQuestions: pendingQuestions,
      childSessions: childSessions,
      statuses: statuses,
      agents: agents,
      providerData: providerData,
      commands: commands,
    );
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
          break;
        case SesoriSessionCreated() ||
            SesoriSessionDeleted() ||
            SesoriSessionDiff() ||
            SesoriSessionError() ||
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
          if (_projectId == null || projectID == _projectId) {
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
    _sendService.drain();
  }

  Future<void> sendMessage({required String text, String? command}) async {
    final current = state;
    await _sendService.sendMessage(
      text: text,
      agent: current is SessionDetailLoaded ? current.selectedAgent : null,
      providerID: current is SessionDetailLoaded ? current.selectedProviderID : null,
      modelID: current is SessionDetailLoaded ? current.selectedModelID : null,
      isConnected: current is SessionDetailLoaded && _isConnected,
      command: command,
    );
  }

  void cancelQueuedMessage(int index) {
    final current = state;
    if (current is! SessionDetailLoaded) return;

    _sendService.cancelQueuedMessage(index);
  }

  /// Syncs queued prompt items into the cubit state.
  void _emitQueueUpdate([SessionDetailLoaded? known]) {
    if (isClosed) return;
    final current = known ?? state;
    if (current is! SessionDetailLoaded) return;
    emit(current.copyWith(queuedMessages: _sendService.queuedMessages));
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
      await _service.replyToQuestion(requestId: requestId, sessionId: sessionId, answers: answers);
      return true;
    } on Object catch (e, st) {
      loge("Failed to reply to question $requestId", e, st);
      await _loadMessages();
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
      await _service.rejectQuestion(requestId);
      return true;
    } on Object catch (e, st) {
      loge("Failed to reject question $requestId", e, st);
      await _loadMessages();
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
      await _loadMessages();
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
      final futures = <Future<void>>[_service.abortSession(_sessionId)];

      // Also abort any active child sessions (busy or retrying).
      if (current is SessionDetailLoaded) {
        for (final entry in current.childStatuses.entries) {
          final status = entry.value;
          if (status is SessionStatusBusy || status is SessionStatusRetry) {
            futures.add(_service.abortSession(entry.key));
          }
        }
      }

      await Future.wait(futures);
    } on Object catch (e, st) {
      loge("Failed to abort session(s)", e, st);
    }
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

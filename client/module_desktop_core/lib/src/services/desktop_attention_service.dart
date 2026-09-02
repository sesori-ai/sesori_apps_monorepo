import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/desktop_attention_preference.dart";
import "../foundation/platform/window_host.dart";
import "../repositories/desktop_instance_repository.dart";

/// Kind of user response requested by a session.
enum _DesktopAttentionKind() {
  permission,
  question,
}

typedef _DesktopAttentionRequest = ({String id, _DesktopAttentionKind kind});

/// Layer-3 owner of desktop SSE-derived native attention notifications.
///
/// The desktop does not register for push. It derives only permission/question
/// attention from the already-authenticated relay stream, displays no prompt or
/// tool payload, and routes notification opens through platform-neutral seams.
@lazySingleton
class DesktopAttentionService({
  required final ConnectionService connectionService,
  required final SessionRepository sessionRepository,
  required final LocalNotificationClient localNotificationClient,
  required final WindowHost windowHost,
  required final DesktopInstanceRepository desktopInstanceRepository,
  required final AuthSession authSession,
  required final RouteDispatcher routeDispatcher,
  required final RouteSource routeSource,
}) {
  final ConnectionService _connectionService = connectionService;
  final SessionRepository _sessionRepository = sessionRepository;
  final LocalNotificationClient _localNotificationClient = localNotificationClient;
  final WindowHost _windowHost = windowHost;
  final DesktopInstanceRepository _desktopInstanceRepository = desktopInstanceRepository;
  final AuthSession _authSession = authSession;
  final RouteDispatcher _routeDispatcher = routeDispatcher;
  final RouteSource _routeSource = routeSource;

  final BehaviorSubject<DesktopAttentionPreference> _preference = BehaviorSubject<DesktopAttentionPreference>.seeded(
    DesktopAttentionPreference.enabled,
  );
  StreamSubscription<SseEvent>? _connectionEventSubscription;
  StreamSubscription<WindowHostState>? _windowStateSubscription;
  StreamSubscription<NotificationOpenRequest>? _notificationOpenSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  final Map<String, Set<_DesktopAttentionRequest>> _pendingRequests = {};
  final Map<String, int> _attentionGenerations = {};
  final Set<Future<void>> _inFlightNotifications = {};
  WindowHostState _windowState = WindowHostState.hidden;
  NotificationOpenRequest? _pendingOpenRequest;
  bool _notificationsAvailable = false;
  bool _logoutSuspended = false;
  bool _authCleanupInProgress = false;
  bool _deferUnauthenticatedOpen = true;
  bool _started = false;
  bool _disposed = false;
  int _nextAttentionGeneration = 0;
  int _authCleanupGeneration = 0;

  ValueStream<DesktopAttentionPreference> get preference => _preference.stream;

  DesktopAttentionPreference get currentPreference => _preference.value;

  Future<void> start() async {
    if (_disposed) {
      logw("DesktopAttentionService.start() called after dispose");
      return;
    }
    if (_started) {
      logw("DesktopAttentionService.start() called more than once; ignoring");
      return;
    }
    _started = true;
    _windowState = _windowHost.currentState;

    try {
      _preference.add(await _desktopInstanceRepository.readAttentionPreference());
    } on Object catch (error, stackTrace) {
      logw("Failed to read the desktop attention-notification preference; using enabled", error, stackTrace);
    }

    try {
      await _localNotificationClient.initialize();
      _notificationsAvailable = true;
    } on Object catch (error, stackTrace) {
      loge("Failed to initialize desktop attention notifications", error, stackTrace);
    }

    _connectionEventSubscription = _connectionService.events.listen(
      (event) => _onConnectionEvent(event: event),
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop attention relay event stream failed", error, stackTrace);
      },
    );
    _windowStateSubscription = _windowHost.states.listen(
      (state) => _windowState = state,
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop attention window-state stream failed", error, stackTrace);
      },
    );
    _notificationOpenSubscription = _localNotificationClient.notificationOpenedStream.listen(
      (request) => _onNotificationOpen(request: request),
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop local-notification open stream failed", error, stackTrace);
      },
    );
    _authSubscription = _authSession.authStateStream.listen(
      (state) => _onAuthState(state: state),
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop attention auth-state stream failed", error, stackTrace);
      },
    );

    if (_notificationsAvailable) {
      try {
        final initialOpen = await _localNotificationClient.getInitialNotificationOpen();
        if (initialOpen != null) {
          _onNotificationOpen(request: initialOpen);
        }
      } on Object catch (error, stackTrace) {
        loge("Failed to read the initial desktop notification open", error, stackTrace);
      }
    }
  }

  Future<void> setPreference({required DesktopAttentionPreference preference}) async {
    if (_disposed) {
      throw StateError("DesktopAttentionService is disposed");
    }
    if (preference == _preference.value) {
      return;
    }
    await _desktopInstanceRepository.writeAttentionPreference(preference: preference);
    _preference.add(preference);
    if (!preference.isEnabled && _notificationsAvailable) {
      _invalidateAllAttention();
      await _settleAndCancelAll(
        failureMessage: "Failed to clear desktop notifications after disabling attention alerts",
      );
    }
  }

  void _onConnectionEvent({required SseEvent event}) {
    final data = event.data;
    if (data case SesoriPermissionAsked(
      :final requestID,
      :final sessionID,
      :final displaySessionId,
    )) {
      _registerAttention(
        sessionId: displaySessionId ?? sessionID,
        request: (id: requestID, kind: _DesktopAttentionKind.permission),
      );
      return;
    }
    if (data case SesoriQuestionAsked(:final id, :final sessionID, :final displaySessionId)) {
      _registerAttention(
        sessionId: displaySessionId ?? sessionID,
        request: (id: id, kind: _DesktopAttentionKind.question),
      );
      return;
    }
    if (data case SesoriPermissionReplied(
      :final requestID,
      :final sessionID,
      :final displaySessionId,
    )) {
      _resolveAttention(
        sessionId: displaySessionId ?? sessionID,
        request: (id: requestID, kind: _DesktopAttentionKind.permission),
      );
      return;
    }
    if (data
        case SesoriQuestionReplied(
              :final requestID,
              :final sessionID,
              :final displaySessionId,
            ) ||
            SesoriQuestionRejected(
              :final requestID,
              :final sessionID,
              :final displaySessionId,
            )) {
      _resolveAttention(
        sessionId: displaySessionId ?? sessionID,
        request: (id: requestID, kind: _DesktopAttentionKind.question),
      );
    }
  }

  void _registerAttention({required String sessionId, required _DesktopAttentionRequest request}) {
    _pendingRequests.putIfAbsent(sessionId, () => <_DesktopAttentionRequest>{}).add(request);
    _queueAttention(
      sessionId: sessionId,
      kind: request.kind,
      generation: _advanceAttentionGeneration(sessionId: sessionId),
    );
  }

  void _resolveAttention({required String sessionId, required _DesktopAttentionRequest request}) {
    final requests = _pendingRequests[sessionId];
    requests?.remove(request);
    final generation = _advanceAttentionGeneration(sessionId: sessionId);
    if (requests == null || requests.isEmpty) {
      _pendingRequests.remove(sessionId);
      unawaited(
        _cancelResolvedAttention(
          sessionId: sessionId,
          generation: generation,
        ),
      );
      return;
    }
    _queueAttention(
      sessionId: sessionId,
      kind: requests.last.kind,
      generation: generation,
    );
  }

  Future<void> _cancelResolvedAttention({required String sessionId, required int generation}) async {
    await _settleInFlightNotifications();
    if (_attentionGenerations[sessionId] != generation || _pendingRequests.containsKey(sessionId)) {
      return;
    }
    _localNotificationClient.cancelForSession(sessionId: sessionId);
  }

  void _queueAttention({
    required String sessionId,
    required _DesktopAttentionKind kind,
    required int generation,
  }) {
    if (_logoutSuspended || _authCleanupInProgress) {
      return;
    }
    final operation = _showAttention(sessionId: sessionId, kind: kind, generation: generation);
    _inFlightNotifications.add(operation);
    unawaited(operation.whenComplete(() => _inFlightNotifications.remove(operation)));
  }

  Future<void> _showAttention({
    required String sessionId,
    required _DesktopAttentionKind kind,
    required int generation,
  }) async {
    if (!_shouldShowAttention(sessionId: sessionId, generation: generation)) {
      return;
    }

    final ApiResponse<Session> response;
    try {
      response = await _sessionRepository.getSession(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      logw("Failed to resolve a session for a desktop attention notification", error, stackTrace);
      return;
    }
    final Session session;
    switch (response) {
      case SuccessResponse(:final data):
        session = data;
      case ErrorResponse(:final error):
        logw("Failed to resolve a session for a desktop attention notification", error);
        return;
    }

    if (!_shouldShowAttention(sessionId: sessionId, generation: generation)) {
      return;
    }
    try {
      await _localNotificationClient.show(
        title: session.title ?? "Sesori",
        body: switch (kind) {
          _DesktopAttentionKind.permission => "Permission approval needed",
          _DesktopAttentionKind.question => "Question waiting for your response",
        },
        category: NotificationCategory.aiInteraction,
        sessionId: session.id,
        projectId: session.projectID,
        sessionTitle: session.title,
      );
    } on Object catch (error, stackTrace) {
      logw("Failed to show a desktop attention notification", error, stackTrace);
    }
  }

  bool _shouldShowAttention({required String sessionId, required int generation}) {
    return !_logoutSuspended &&
        !_authCleanupInProgress &&
        _attentionGenerations[sessionId] == generation &&
        (_pendingRequests[sessionId]?.isNotEmpty ?? false) &&
        _notificationsAvailable &&
        _preference.value.isEnabled &&
        _windowState != WindowHostState.focused &&
        _authSession.currentState is AuthAuthenticated;
  }

  /// Stops new alerts synchronously and waits for already-started native
  /// notification writes so logout can cancel them in a deterministic order.
  Future<void> suspendForLogout() {
    _logoutSuspended = true;
    _invalidateAllAttention();
    return _settleInFlightNotifications();
  }

  /// Restores attention handling when a logout attempt finishes. A successful
  /// logout remains suppressed by the unauthenticated-state check.
  void resumeAfterLogoutAttempt() {
    if (_disposed) {
      return;
    }
    _logoutSuspended = false;
    _resumePendingAttention();
  }

  void _resumePendingAttention() {
    if (_disposed || _logoutSuspended || _authCleanupInProgress || _authSession.currentState is! AuthAuthenticated) {
      return;
    }
    for (final entry in _pendingRequests.entries) {
      if (entry.value.isEmpty) {
        continue;
      }
      _queueAttention(
        sessionId: entry.key,
        kind: entry.value.last.kind,
        generation: _advanceAttentionGeneration(sessionId: entry.key),
      );
    }
  }

  int _advanceAttentionGeneration({required String sessionId}) {
    final generation = ++_nextAttentionGeneration;
    _attentionGenerations[sessionId] = generation;
    return generation;
  }

  void _invalidateAllAttention() {
    for (final sessionId in _attentionGenerations.keys.toList(growable: false)) {
      _advanceAttentionGeneration(sessionId: sessionId);
    }
  }

  Future<void> _settleInFlightNotifications() async {
    await Future.wait<void>(_inFlightNotifications.toList(growable: false));
  }

  Future<void> _settleAndCancelAll({required String failureMessage}) async {
    await _settleInFlightNotifications();
    try {
      await _localNotificationClient.cancelAll();
    } on Object catch (error, stackTrace) {
      logw(failureMessage, error, stackTrace);
    }
  }

  void _beginAuthCleanup() {
    final generation = ++_authCleanupGeneration;
    if (!_notificationsAvailable) {
      _authCleanupInProgress = false;
      return;
    }
    _authCleanupInProgress = true;
    final operation = _settleAndCancelAll(
      failureMessage: "Failed to clear desktop notifications after authentication ended",
    );
    unawaited(_finishAuthCleanup(operation: operation, generation: generation));
  }

  Future<void> _finishAuthCleanup({required Future<void> operation, required int generation}) async {
    try {
      await operation;
    } finally {
      if (_authCleanupGeneration == generation) {
        _authCleanupInProgress = false;
        _resumePendingAttention();
      }
    }
  }

  void _onNotificationOpen({required NotificationOpenRequest request}) {
    if (_logoutSuspended || _authCleanupInProgress) {
      return;
    }
    if (_authSession.currentState is! AuthAuthenticated) {
      if (_deferUnauthenticatedOpen) {
        _pendingOpenRequest = request;
      }
      return;
    }
    unawaited(_openNotification(request: request));
  }

  void _onAuthState({required AuthState state}) {
    switch (state) {
      case AuthAuthenticated():
        _deferUnauthenticatedOpen = true;
        final pending = _pendingOpenRequest;
        if (pending == null) {
          return;
        }
        _pendingOpenRequest = null;
        unawaited(_openNotification(request: pending));
      case AuthUnauthenticated() || AuthFailed():
        _deferUnauthenticatedOpen = false;
        _pendingOpenRequest = null;
        _pendingRequests.clear();
        _attentionGenerations.clear();
        _beginAuthCleanup();
      case AuthInitial() || AuthAuthenticating():
        return;
    }
  }

  Future<void> _openNotification({required NotificationOpenRequest request}) async {
    try {
      await _windowHost.show();
    } on Object catch (error, stackTrace) {
      logw("Failed to focus the desktop window for a notification open", error, stackTrace);
    }

    final sessionDetail = AppRouteSessionDetail(
      projectId: request.projectId,
      projectName: null,
      sessionId: request.sessionId,
      sessionTitle: request.sessionTitle,
      readOnly: false,
    );
    final currentLocation = _routeSource.currentLocation;
    if (currentLocation != null && sessionDetail.showsEditableLocation(location: Uri.parse(currentLocation))) {
      return;
    }
    _routeDispatcher.replaceStack(
      stack: RouteStack(
        paths: <AppRoute>[
          const AppRoute.projects(),
          AppRoute.sessions(projectId: request.projectId, projectName: null),
          sessionDetail,
        ].map((route) => route.buildPath()).toList(growable: false),
      ),
    );
  }

  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _authSubscription?.cancel();
    await _notificationOpenSubscription?.cancel();
    await _windowStateSubscription?.cancel();
    await _connectionEventSubscription?.cancel();
    await _settleInFlightNotifications();
    await _preference.close();
  }
}

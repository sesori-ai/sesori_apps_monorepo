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
  WindowHostState _windowState = WindowHostState.hidden;
  NotificationOpenRequest? _pendingOpenRequest;
  bool _notificationsAvailable = false;
  bool _started = false;
  bool _disposed = false;

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
      try {
        await _localNotificationClient.cancelAll();
      } on Object catch (error, stackTrace) {
        logw("Failed to clear desktop notifications after disabling attention alerts", error, stackTrace);
      }
    }
  }

  void _onConnectionEvent({required SseEvent event}) {
    final data = event.data;
    if (data case SesoriPermissionAsked(:final sessionID, :final displaySessionId)) {
      unawaited(
        _showAttention(
          sessionId: displaySessionId ?? sessionID,
          kind: _DesktopAttentionKind.permission,
        ),
      );
      return;
    }
    if (data case SesoriQuestionAsked(:final sessionID, :final displaySessionId)) {
      unawaited(
        _showAttention(
          sessionId: displaySessionId ?? sessionID,
          kind: _DesktopAttentionKind.question,
        ),
      );
      return;
    }
    if (data
        case SesoriPermissionReplied(:final sessionID, :final displaySessionId) ||
            SesoriQuestionReplied(:final sessionID, :final displaySessionId) ||
            SesoriQuestionRejected(:final sessionID, :final displaySessionId)) {
      _localNotificationClient.cancelForSession(sessionId: displaySessionId ?? sessionID);
    }
  }

  Future<void> _showAttention({required String sessionId, required _DesktopAttentionKind kind}) async {
    if (!_shouldNotify) {
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

    if (!_shouldNotify) {
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

  bool get _shouldNotify {
    return _notificationsAvailable &&
        _preference.value.isEnabled &&
        _windowState != WindowHostState.focused &&
        _authSession.currentState is AuthAuthenticated;
  }

  void _onNotificationOpen({required NotificationOpenRequest request}) {
    if (_authSession.currentState is! AuthAuthenticated) {
      _pendingOpenRequest = request;
      return;
    }
    unawaited(_openNotification(request: request));
  }

  void _onAuthState({required AuthState state}) {
    switch (state) {
      case AuthAuthenticated():
        final pending = _pendingOpenRequest;
        if (pending == null) {
          return;
        }
        _pendingOpenRequest = null;
        unawaited(_openNotification(request: pending));
      case AuthUnauthenticated() || AuthFailed():
        _pendingOpenRequest = null;
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
    await _preference.close();
  }
}

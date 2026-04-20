import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";
import "../platform/local_notification_client.dart";
import "../platform/notification_open_request.dart";
import "../platform/push_messaging_source.dart";
import "../platform/route_dispatcher.dart";
import "app_routes.dart";

@lazySingleton
class NotificationOpenDispatcher {
  final AuthSession _authSession;
  final PushMessagingSource _pushMessagingSource;
  final LocalNotificationClient _localNotificationClient;
  final RouteDispatcher _routeDispatcher;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<NotificationOpenRequest>? _pushOpenSubscription;
  StreamSubscription<NotificationOpenRequest>? _localOpenSubscription;
  NotificationOpenRequest? _pendingOpenRequest;
  bool _started = false;
  bool _disposed = false;

  NotificationOpenDispatcher({
    required AuthSession authSession,
    required PushMessagingSource pushMessagingSource,
    required LocalNotificationClient localNotificationClient,
    required RouteDispatcher routeDispatcher,
  }) : _authSession = authSession,
       _pushMessagingSource = pushMessagingSource,
       _localNotificationClient = localNotificationClient,
       _routeDispatcher = routeDispatcher;

  Future<void> start() async {
    if (_disposed) {
      logw("NotificationOpenDispatcher.start() called after dispose");
      return;
    }
    if (_started) {
      logw("NotificationOpenDispatcher.start() called more than once; ignoring");
      return;
    }

    _started = true;
    _authSubscription = _authSession.authStateStream.listen(_onAuthStateChanged, onError: _onAuthStreamError);
    _pushOpenSubscription = _pushMessagingSource.notificationOpenedStream.listen(
      _handleNotificationOpen,
      onError: _onPushOpenError,
    );
    _localOpenSubscription = _localNotificationClient.notificationOpenedStream.listen(
      _handleNotificationOpen,
      onError: _onLocalOpenError,
    );

    await Future.wait<void>([
      _consumeInitialOpen(_pushMessagingSource.getInitialNotificationOpen()),
      _consumeInitialOpen(_localNotificationClient.getInitialNotificationOpen()),
    ]);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _authSubscription?.cancel();
    await _pushOpenSubscription?.cancel();
    await _localOpenSubscription?.cancel();
    _authSubscription = null;
    _pushOpenSubscription = null;
    _localOpenSubscription = null;
  }

  Future<void> _consumeInitialOpen(Future<NotificationOpenRequest?> future) async {
    try {
      final request = await future;
      if (request != null) {
        _handleNotificationOpen(request);
      }
    } catch (error, stackTrace) {
      loge("Failed to read initial notification open", error, stackTrace);
    }
  }

  void _handleNotificationOpen(NotificationOpenRequest request) {
    if (_disposed) {
      return;
    }
    if (_authSession.currentState is! AuthAuthenticated) {
      _pendingOpenRequest = request;
      return;
    }

    _dispatch(request);
  }

  void _onAuthStateChanged(AuthState state) {
    switch (state) {
      case AuthAuthenticated():
        final pendingOpenRequest = _pendingOpenRequest;
        if (pendingOpenRequest == null) {
          return;
        }
        _pendingOpenRequest = null;
        _dispatch(pendingOpenRequest);
      case AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed():
        return;
    }
  }

  void _dispatch(NotificationOpenRequest request) {
    _routeDispatcher.replaceStack(
      stack: RouteStack(
        paths: [
          const AppRoute.projects(),
          AppRoute.sessions(projectId: request.projectId, projectName: null),
          AppRoute.sessionDetail(
            projectId: request.projectId,
            sessionId: request.sessionId,
            sessionTitle: request.sessionTitle,
            readOnly: false,
          ),
        ].map((route) => route.buildPath()).toList(growable: false),
      ),
    );
  }

  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    loge("Notification open auth state stream error", error, stackTrace);
  }

  void _onPushOpenError(Object error, StackTrace stackTrace) {
    loge("Push notification open stream error", error, stackTrace);
  }

  void _onLocalOpenError(Object error, StackTrace stackTrace) {
    loge("Local notification open stream error", error, stackTrace);
  }
}

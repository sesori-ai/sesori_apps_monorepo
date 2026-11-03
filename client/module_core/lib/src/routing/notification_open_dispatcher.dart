import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../logging/logging.dart";
import "../platform/local_notification_client.dart";
import "../platform/notification_open_request.dart";
import "../platform/push_messaging_source.dart";
import "../platform/route_dispatcher.dart";
import "../platform/route_source.dart";
import "../services/selected_computer_service.dart";
import "computer_switch_dispatcher.dart";
import "notification_session_route.dart";

@lazySingleton
class NotificationOpenDispatcher({
  required final AuthSession _authSession,
  required final PushMessagingSource _pushMessagingSource,
  required final LocalNotificationClient _localNotificationClient,
  required final RouteDispatcher _routeDispatcher,
  required final RouteSource _routeSource,
  required final SelectedComputerService _selectedComputerService,
  required final ComputerSwitchDispatcher _computerSwitchDispatcher,
}) {
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<NotificationOpenRequest>? _pushOpenSubscription;
  StreamSubscription<NotificationOpenRequest>? _localOpenSubscription;
  NotificationOpenRequest? _pendingOpenRequest;
  bool _started = false;
  bool _disposed = false;

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

    unawaited(_dispatch(request));
  }

  void _onAuthStateChanged(AuthState state) {
    switch (state) {
      case AuthAuthenticated():
        final pendingOpenRequest = _pendingOpenRequest;
        if (pendingOpenRequest == null) {
          return;
        }
        _pendingOpenRequest = null;
        unawaited(_dispatch(pendingOpenRequest));
      case AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed():
        return;
    }
  }

  Future<void> _dispatch(NotificationOpenRequest request) async {
    final bridgeId = request.bridgeId;
    final bool switchedComputer;
    if (bridgeId != null && bridgeId != await _selectedComputerService.targetBridgeId()) {
      // The switch returns to the home and retargets the connection before the
      // session screen is built, so that screen waits for the new computer's
      // connection and loads the session there, as after a cold launch.
      await _computerSwitchDispatcher.switchTo(bridgeId: bridgeId, source: ComputerSwitchSource.notification);
      switchedComputer = true;
    } else {
      switchedComputer = false;
    }
    openNotificationSession(
      request: request,
      routeDispatcher: _routeDispatcher,
      routeSource: _routeSource,
      keepIfAlreadyShown: !switchedComputer,
    );
  }

  // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters
  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    loge("Notification open auth state stream error", error, stackTrace);
  }

  // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters
  void _onPushOpenError(Object error, StackTrace stackTrace) {
    loge("Push notification open stream error", error, stackTrace);
  }

  // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters
  void _onLocalOpenError(Object error, StackTrace stackTrace) {
    loge("Local notification open stream error", error, stackTrace);
  }
}

import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";
import "../platform/push_messaging_source.dart";
import "../repositories/notification_repository.dart";

@lazySingleton
class NotificationRegistrationService {
  final NotificationRepository _repository;
  final AuthSession _authSession;
  final PushMessagingSource _pushMessagingSource;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentRegisteredToken;
  bool _ignoreNextAuthStateEmission = false;
  bool _started = false;
  bool _disposed = false;

  NotificationRegistrationService({
    required NotificationRepository repository,
    required AuthSession authSession,
    required PushMessagingSource pushMessagingSource,
  }) : _repository = repository,
       _authSession = authSession,
       _pushMessagingSource = pushMessagingSource;

  Future<void> start() async {
    if (_disposed) {
      logw("NotificationRegistrationService.start() called after dispose");
      return;
    }
    if (_started) {
      logw("NotificationRegistrationService.start() called more than once; ignoring");
      return;
    }

    try {
      await _syncForState(state: _authSession.currentState);
      _ignoreNextAuthStateEmission = true;
      _authSubscription = _authSession.authStateStream.listen(_onAuthStateChanged, onError: _onAuthStreamError);
      _tokenRefreshSubscription = _pushMessagingSource.tokenRefreshStream.listen(
        _onTokenRefresh,
        onError: _onTokenRefreshStreamError,
      );
      _started = true;
    } catch (error, stackTrace) {
      _ignoreNextAuthStateEmission = false;
      _started = false;
      await _authSubscription?.cancel();
      await _tokenRefreshSubscription?.cancel();
      _authSubscription = null;
      _tokenRefreshSubscription = null;
      logw("Failed to start notification registration", error, stackTrace);
    }
  }

  Future<void> _syncForState({required AuthState state}) async {
    switch (state) {
      case AuthAuthenticated():
        await _registerCurrentToken();
      case AuthUnauthenticated() || AuthFailed():
        await _unregisterCurrentToken();
      case AuthInitial() || AuthAuthenticating():
        return;
    }
  }

  Future<void> _registerCurrentToken() async {
    final token = await _pushMessagingSource.getToken();
    if (token == null || token.isEmpty || token == _currentRegisteredToken) {
      return;
    }

    await _repository.registerToken(token: token, platform: _pushMessagingSource.devicePlatform);
    _currentRegisteredToken = token;
  }

  Future<void> _unregisterCurrentToken() async {
    final token = _currentRegisteredToken;
    if (token == null) {
      return;
    }

    await _repository.unregisterToken(token: token);
    _currentRegisteredToken = null;
  }

  void _onAuthStateChanged(AuthState state) {
    if (_ignoreNextAuthStateEmission && state == _authSession.currentState) {
      _ignoreNextAuthStateEmission = false;
      return;
    }
    _ignoreNextAuthStateEmission = false;

    unawaited(_syncForState(state: state).catchError((Object error, StackTrace stackTrace) {
      logw("Failed to sync push token for auth state change", error, stackTrace);
    }));
  }

  void _onTokenRefresh(String newToken) {
    unawaited(_handleTokenRefresh(newToken: newToken).catchError((Object error, StackTrace stackTrace) {
      logw("Failed to sync refreshed push token", error, stackTrace);
    }));
  }

  Future<void> _handleTokenRefresh({required String newToken}) async {
    final oldToken = _currentRegisteredToken;
    if (oldToken != null && oldToken != newToken) {
      try {
        await _repository.unregisterToken(token: oldToken);
      } catch (error, stackTrace) {
        logw("Failed to unregister old push token", error, stackTrace);
      }
      _currentRegisteredToken = null;
    }

    if (_authSession.currentState is! AuthAuthenticated || newToken.isEmpty) {
      return;
    }

    await _repository.registerToken(token: newToken, platform: _pushMessagingSource.devicePlatform);
    _currentRegisteredToken = newToken;
  }

  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    loge("Notification registration auth state stream error", error, stackTrace);
  }

  void _onTokenRefreshStreamError(Object error, StackTrace stackTrace) {
    loge("Notification registration token refresh stream error", error, stackTrace);
  }

  @disposeMethod
  Future<void> dispose() async {
    _disposed = true;
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _authSubscription = null;
    _tokenRefreshSubscription = null;
  }
}

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
  AuthState? _initialAuthStateToIgnore;
  Future<void> _syncQueue = Future<void>.value();
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

    final initialState = _authSession.currentState;
    _started = true;
    _initialAuthStateToIgnore = initialState;
    _authSubscription = _authSession.authStateStream.listen(_onAuthStateChanged, onError: _onAuthStreamError);
    _tokenRefreshSubscription = _pushMessagingSource.tokenRefreshStream.listen(
      _onTokenRefresh,
      onError: _onTokenRefreshStreamError,
    );

    try {
      await _enqueueSync(() => _syncForState(state: initialState));
    } catch (error, stackTrace) {
      logw("Failed to start notification registration", error, stackTrace);
    }
  }

  Future<void> _enqueueSync(Future<void> Function() operation) {
    final next = _syncQueue.catchError((Object _, StackTrace __) {}).then((_) => operation());
    _syncQueue = next.catchError((Object _, StackTrace __) {});
    return next;
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
    final token = _currentRegisteredToken ?? await _pushMessagingSource.getToken();
    if (token == null) {
      return;
    }

    await _repository.unregisterToken(token: token);
    _currentRegisteredToken = null;
  }

  void _onAuthStateChanged(AuthState state) {
    if (_initialAuthStateToIgnore != null && state == _initialAuthStateToIgnore) {
      _initialAuthStateToIgnore = null;
      return;
    }
    _initialAuthStateToIgnore = null;

    unawaited(
      _enqueueSync(() => _syncForState(state: state)).catchError((Object error, StackTrace stackTrace) {
        logw("Failed to sync push token for auth state change", error, stackTrace);
      }),
    );
  }

  void _onTokenRefresh(String newToken) {
    unawaited(
      _enqueueSync(() => _handleTokenRefresh(newToken: newToken)).catchError((Object error, StackTrace stackTrace) {
        logw("Failed to sync refreshed push token", error, stackTrace);
      }),
    );
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

  // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters
  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    loge("Notification registration auth state stream error", error, stackTrace);
  }

  // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters
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

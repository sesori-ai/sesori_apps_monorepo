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
  bool _localTokenDeleted = false;
  bool _registrationSuspended = false;
  bool _unauthenticatedObservedWhileSuspended = false;
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

  /// Stops push delivery for this installation before local auth is cleared.
  /// Cleanup is best-effort so a failure cannot prevent local logout.
  Future<void> unregisterCurrentDevice() {
    return _enqueueSync(_unregisterCurrentDevice);
  }

  /// Restores push registration when local auth remains after logout fails.
  Future<void> resumeRegistrationAfterFailedLogout() {
    return _enqueueSync(_resumeRegistrationAfterFailedLogout);
  }

  Future<void> _syncForState({required AuthState state}) async {
    switch (state) {
      case AuthAuthenticated():
        if (_registrationSuspended) {
          if (!_unauthenticatedObservedWhileSuspended) return;
          _registrationSuspended = false;
          _unauthenticatedObservedWhileSuspended = false;
        }
        await _registerCurrentToken();
      case AuthUnauthenticated() || AuthFailed():
        if (_registrationSuspended) {
          _unauthenticatedObservedWhileSuspended = true;
        }
        await _deleteLocalToken();
      case AuthInitial() || AuthAuthenticating():
        return;
    }
  }

  Future<void> _registerCurrentToken() async {
    final token = await _pushMessagingSource.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    _localTokenDeleted = false;
    if (token == _currentRegisteredToken) return;

    await _repository.registerToken(token: token, platform: _pushMessagingSource.devicePlatform);
    _currentRegisteredToken = token;
  }

  Future<void> _unregisterCurrentDevice() async {
    // Do not let queued auth work or a refresh re-register before logout.
    _registrationSuspended = true;
    _unauthenticatedObservedWhileSuspended = false;

    var token = _currentRegisteredToken;
    if (token == null && !_localTokenDeleted) {
      try {
        token = await _pushMessagingSource.getToken();
        if (token != null && token.isNotEmpty) {
          _localTokenDeleted = false;
        }
      } catch (error, stackTrace) {
        logw("Failed to read push token during logout", error, stackTrace);
      }
    }

    if (token != null && token.isNotEmpty) {
      try {
        await _repository.unregisterToken(token: token);
        _currentRegisteredToken = null;
      } catch (error, stackTrace) {
        logw("Failed to unregister push token during logout", error, stackTrace);
      }
    }
  }

  Future<void> _resumeRegistrationAfterFailedLogout() async {
    if (_authSession.currentState is! AuthAuthenticated) return;

    _registrationSuspended = false;
    _unauthenticatedObservedWhileSuspended = false;
    await _registerCurrentToken();
  }

  Future<void> _deleteLocalToken() async {
    if (_localTokenDeleted) {
      _currentRegisteredToken = null;
      return;
    }

    try {
      await _pushMessagingSource.deleteToken();
      _localTokenDeleted = true;
    } finally {
      _currentRegisteredToken = null;
    }
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
    if (newToken.isEmpty) return;

    _localTokenDeleted = false;
    final authState = _authSession.currentState;
    if (_registrationSuspended && authState is AuthAuthenticated) {
      return;
    }
    if (authState is! AuthAuthenticated) {
      await _syncForState(state: authState);
      return;
    }

    final oldToken = _currentRegisteredToken;
    if (oldToken != null && oldToken != newToken) {
      try {
        await _repository.unregisterToken(token: oldToken);
      } catch (error, stackTrace) {
        logw("Failed to unregister old push token", error, stackTrace);
      }
      _currentRegisteredToken = null;
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

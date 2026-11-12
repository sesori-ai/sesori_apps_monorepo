import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";
import "../platform/push_messaging_source.dart";
import "../repositories/notification_repository.dart";

/// How long logout cleanup may hold the sync queue. The unregister request has
/// no timeout of its own; past this, later push work runs while the request
/// finishes or fails in the background.
const _logoutCleanupDeadline = Duration(seconds: 5);

@lazySingleton
class NotificationRegistrationService({
  required final NotificationRepository _repository,
  required final AuthSession _authSession,
  required final PushMessagingSource _pushMessagingSource,
}) {
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _registeredFidSubscription;

  /// The latest FID the messaging provider reported, so logout can remove it
  /// from the server even when its registration there failed during this run.
  String? _latestFid;

  /// The FID the server last accepted, so repeated reports of it are not resent.
  String? _registeredFid;
  AuthState? _initialAuthStateToIgnore;
  Future<void> _syncQueue = Future<void>.value();
  bool _locallyUnregistered = false;
  bool _registrationSuspended = false;
  bool _unauthenticatedObservedWhileSuspended = false;
  bool _started = false;
  bool _disposed = false;

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
    // Subscribed before the first registration request: the FID only ever
    // arrives as an event.
    _registeredFidSubscription = _pushMessagingSource.registeredFidStream.listen(
      _onRegisteredFid,
      onError: _onRegisteredFidStreamError,
    );

    try {
      await _enqueueSync(() => _syncForState(state: initialState));
    } catch (error, stackTrace) {
      logw("Failed to start notification registration", error, stackTrace);
    }
  }

  Future<void> _enqueueSync(Future<void> Function() operation) {
    final next = _syncQueue.catchError((Object _, StackTrace _) {}).then((_) => operation());
    _syncQueue = next.catchError((Object _, StackTrace _) {});
    return next;
  }

  /// Stops push delivery for this installation before local auth is cleared.
  /// Cleanup is best-effort so a failure cannot prevent local logout, and it
  /// is bounded so a stalled request cannot block later push work.
  Future<void> unregisterCurrentDevice() {
    return _enqueueSync(() => _unregisterCurrentDevice().timeout(_logoutCleanupDeadline));
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
        await _requestRegistration();
      case AuthUnauthenticated() || AuthFailed():
        if (_registrationSuspended) {
          _unauthenticatedObservedWhileSuspended = true;
        }
        await _unregisterLocally();
      case AuthInitial() || AuthAuthenticating():
        return;
    }
  }

  /// The resulting FID reaches the server through [_handleRegisteredFid].
  Future<void> _requestRegistration() async {
    _locallyUnregistered = false;
    await _pushMessagingSource.register();
  }

  Future<void> _unregisterCurrentDevice() async {
    // Do not let queued auth work or a registration event re-register before logout.
    _registrationSuspended = true;
    _unauthenticatedObservedWhileSuspended = false;

    final fid = _latestFid;
    if (fid == null) return;
    // Cleared before the request: once the deadline passes it finishes in the
    // background, and a failed logout's resumed registration must re-send the
    // FID rather than skip it as already registered.
    _registeredFid = null;
    try {
      await _repository.unregisterFid(fid: fid);
      logi("Push FID ${_fidForLog(fid)} unregistered from the server for logout");
    } catch (error, stackTrace) {
      logw("Failed to unregister push FID during logout", error, stackTrace);
    }
  }

  Future<void> _resumeRegistrationAfterFailedLogout() async {
    if (_authSession.currentState is! AuthAuthenticated) return;

    _registrationSuspended = false;
    _unauthenticatedObservedWhileSuspended = false;
    await _requestRegistration();
  }

  Future<void> _unregisterLocally() async {
    if (_locallyUnregistered) {
      _registeredFid = null;
      return;
    }

    try {
      await _pushMessagingSource.unregister();
      _locallyUnregistered = true;
      logi("Unregistered from FCM and retired this installation's FID");
    } finally {
      _registeredFid = null;
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
        logw("Failed to sync push registration for auth state change", error, stackTrace);
      }),
    );
  }

  void _onRegisteredFid(String fid) {
    unawaited(
      _enqueueSync(() => _handleRegisteredFid(fid: fid)).catchError((Object error, StackTrace stackTrace) {
        logw("Failed to register push FID with the server", error, stackTrace);
      }),
    );
  }

  Future<void> _handleRegisteredFid({required String fid}) async {
    logi("Push FID ${_fidForLog(fid)} received from FCM");
    _latestFid = fid;
    _locallyUnregistered = false;
    final authState = _authSession.currentState;
    if (_registrationSuspended && authState is AuthAuthenticated) {
      return;
    }
    if (authState is! AuthAuthenticated) {
      // An FID reported while not signed in never reaches the server. After a
      // sign-out (logout or a rejected session) this unregisters it again and
      // retires it. A cold start while signed out stays AuthInitial, so FCM
      // keeps the registration it made by itself, but that FID is new since
      // the sign-out and the server never stored it. Only a retire that failed
      // (offline) leaves an FID the server may still hold; see
      // docs/regression/notifications.md.
      await _syncForState(state: authState);
      return;
    }
    if (fid == _registeredFid) {
      logd("Push FID ${_fidForLog(fid)} is already registered with the server");
      return;
    }

    final previousFid = _registeredFid;
    if (previousFid != null) {
      try {
        await _repository.unregisterFid(fid: previousFid);
        logi("Previous push FID ${_fidForLog(previousFid)} unregistered from the server");
      } catch (error, stackTrace) {
        logw("Failed to unregister previous push FID", error, stackTrace);
      }
      _registeredFid = null;
    }

    await _repository.registerFid(fid: fid, platform: _pushMessagingSource.devicePlatform);
    _registeredFid = fid;
    logi("Push FID ${_fidForLog(fid)} registered with the server");
  }

  // ignore: no_slop_linter/prefer_required_named_parameters
  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    loge("Notification registration auth state stream error", error, stackTrace);
  }

  // ignore: no_slop_linter/prefer_required_named_parameters
  void _onRegisteredFidStreamError(Object error, StackTrace stackTrace) {
    loge("Notification registration FID stream error", error, stackTrace);
  }

  @disposeMethod
  Future<void> dispose() async {
    _disposed = true;
    await _authSubscription?.cancel();
    await _registeredFidSubscription?.cancel();
    _authSubscription = null;
    _registeredFidSubscription = null;
  }
}

/// An FID is this installation's push delivery address, so logs carry only a
/// prefix: enough to match a server-side record, not enough to send to.
String _fidForLog(String fid) => fid.length > 6 ? "${fid.substring(0, 6)}…" : fid;

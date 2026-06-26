import "dart:async";

import "package:bloc/bloc.dart";
import "package:http/http.dart" show ClientException;
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../platform/lifecycle_source.dart";
import "../../platform/url_launcher.dart";
import "login_failed_reason.dart";
import "login_state.dart";

class LoginCubit extends Cubit<LoginState> {
  final OAuthFlowProvider _oAuthFlowProvider;
  final UrlLauncher _urlLauncher;
  final AuthSession _authSession;
  final LifecycleSource _lifecycleSource;
  StreamSubscription<LifecycleState>? _lifecycleSubscription;
  bool _isPolling = false;

  /// Whether the app is currently backgrounded. While backgrounded, the OS can
  /// abort the in-flight OAuth status poll (Android tears down the socket when
  /// the auth browser opens). Such interruptions are recoverable on resume, so
  /// they must not be surfaced as terminal login failures.
  bool _isInBackground = false;

  /// Whether the currently-settling poll observed a lifecycle transition away
  /// from resumed. Kept separate from [_isInBackground] so a late transport
  /// abort from the original poll is still treated as recoverable even if the
  /// app has already returned to the foreground before the Future completes.
  bool _didActivePollEnterBackground = false;

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  LoginCubit(
    OAuthFlowProvider oAuthFlowProvider,
    UrlLauncher urlLauncher,
    AuthSession authSession,
    LifecycleSource lifecycleSource,
  ) : _oAuthFlowProvider = oAuthFlowProvider,
      _urlLauncher = urlLauncher,
      _authSession = authSession,
      _lifecycleSource = lifecycleSource,
      super(const LoginState.idle()) {
    _lifecycleSubscription = _lifecycleSource.lifecycleStateStream.listen((state) {
      switch (state) {
        case LifecycleState.paused:
        case LifecycleState.inactive:
        case LifecycleState.hidden:
        case LifecycleState.detached:
          _isInBackground = true;
          if (_isPolling) {
            _didActivePollEnterBackground = true;
          }
        case LifecycleState.resumed:
          _isInBackground = false;
          _onAppResumed().catchError((Object e, StackTrace st) {
            loge("OAuth resume check failed", e, st);
            if (!isClosed) {
              emit(const LoginState.failed(reason: LoginFailedReason.unknown));
            }
          });
      }
    });
  }

  @override
  Future<void> close() async {
    await _lifecycleSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAppResumed() async {
    if (_isPolling) return;
    if (state is LoginPolling || state is LoginTimeout) {
      final hasActiveSession = await _oAuthFlowProvider.hasActiveOAuthSession();
      if (!hasActiveSession) {
        // A background interruption parks the flow in LoginPolling. If the
        // session has since expired/cleared, reset to idle instead of leaving
        // a permanently stuck spinner.
        if (state is LoginPolling) {
          if (isClosed) return;
          emit(const LoginState.idle());
        }
        return;
      }
      if (isClosed) return;

      _didActivePollEnterBackground = _isInBackground;
      _isPolling = true;
      emit(const LoginState.polling());
      try {
        await _oAuthFlowProvider.resumeOAuthFlow();
        if (isClosed) return;
        emit(const LoginState.success());
      } on TimeoutException catch (e, st) {
        loge("OAuth resumed but timed out", e, st);
        if (isClosed) return;
        emit(const LoginState.timeout());
      } catch (e, st) {
        if (_handlePollInterruption(error: e)) return;
        loge("OAuth resumed but failed", e, st);
        if (isClosed) return;
        emit(const LoginState.failed(reason: LoginFailedReason.unknown));
      } finally {
        _isPolling = false;
      }
    }
  }

  /// When a poll has a transport failure while the app is/was backgrounded, the
  /// failure is almost certainly the OS aborting the in-flight request (e.g.
  /// Android tearing down the socket when the OAuth browser opens), not a real
  /// authorization failure. Park the UI in a resumable, no-error [LoginPolling]
  /// state so [_onAppResumed] can retry once the app returns to the foreground.
  ///
  /// Returns true when the error was handled as a recoverable interruption, in
  /// which case the caller must stop and not emit a failure state.
  bool _handlePollInterruption({required Object error}) {
    if (!_isRecoverablePollInterruption(error)) return false;
    if (!_isInBackground && !_didActivePollEnterBackground) return false;
    final alreadyForeground = !_isInBackground;
    _didActivePollEnterBackground = false;
    if (isClosed) return true;
    emit(const LoginState.polling());
    if (alreadyForeground) {
      // The app already returned to the foreground before this abort surfaced,
      // so no further `resumed` lifecycle event will arrive to drive recovery.
      // Kick the retry now; the microtask lets the caller's `finally` clear
      // `_isPolling` before `_onAppResumed` runs.
      Future.microtask(() {
        if (isClosed) return;
        _onAppResumed().catchError((Object e, StackTrace st) {
          loge("OAuth retry after interruption failed", e, st);
          if (!isClosed) {
            emit(const LoginState.failed(reason: LoginFailedReason.unknown));
          }
        });
      });
    }
    return true;
  }

  /// Only a transport-level abort (the OS tearing down the in-flight socket when
  /// the app is backgrounded) is treated as a recoverable interruption. A
  /// [TimeoutException] is the terminal "OAuth authorization timed out" signal
  /// and must surface as [LoginTimeout], not be silently parked.
  bool _isRecoverablePollInterruption(Object error) => error is ClientException;

  Future<bool> loginWithProvider(OAuthProvider provider) async {
    emit(const LoginState.authenticating());

    try {
      final initResponse = await _oAuthFlowProvider.startOAuthFlow(provider: provider);
      if (isClosed) return false;

      logd("Opening ${provider.label} auth URL in browser");

      final launched = await _urlLauncher.launch(Uri.parse(initResponse.authUrl));

      if (isClosed) return false;

      if (!launched) {
        emit(const LoginState.failed(reason: LoginFailedReason.browserOpenFailed));
        return false;
      }

      _didActivePollEnterBackground = _isInBackground;
      _isPolling = true;
      emit(const LoginState.polling());
      try {
        await _oAuthFlowProvider.pollForResult();
      } finally {
        _isPolling = false;
      }

      if (isClosed) return false;
      emit(const LoginState.success());
      return true;
    } on TimeoutException catch (e, st) {
      loge("${provider.label} login timed out", e, st);
      if (isClosed) return false;
      emit(const LoginState.timeout());
      return false;
    } catch (e, st) {
      if (_handlePollInterruption(error: e)) return false;
      loge("${provider.label} login failed", e, st);
      if (isClosed) return false;
      emit(const LoginState.failed(reason: LoginFailedReason.unknown));
      return false;
    }
  }

  void onMissingFormKey() {
    emit(const LoginState.failed(reason: LoginFailedReason.unknown));
  }

  /// Clears the [LoginFailed] state and returns to idle. Used when the user
  /// dismisses the login failure error notification on the login screen.
  void onDismissedLoginFailureError() {
    if (state is LoginFailed) {
      emit(const LoginState.idle());
    }
  }

  void onMissingAppleIdToken() {
    emit(const LoginState.failed(reason: LoginFailedReason.appleIdTokenMissing));
  }

  void onAppleSignInError() {
    emit(const LoginState.failed(reason: LoginFailedReason.unknown));
  }

  Future<bool> loginWithApple({
    required String idToken,
    required String nonce,
  }) async {
    emit(const LoginState.authenticating());

    try {
      await _authSession.loginWithApple(idToken: idToken, nonce: nonce);
      if (isClosed) return false;
      emit(const LoginState.success());
      return true;
    } catch (e, st) {
      loge("Apple login failed", e, st);
      if (isClosed) return false;
      emit(const LoginState.failed(reason: LoginFailedReason.unknown));
      return false;
    }
  }

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty) {
      emit(const LoginState.failed(reason: LoginFailedReason.emailRequired));
      return false;
    }

    if (password.isEmpty) {
      emit(const LoginState.failed(reason: LoginFailedReason.passwordRequired));
      return false;
    }

    emit(const LoginState.authenticating());

    try {
      await _authSession.loginWithEmail(email: email.trim(), password: password);
      if (isClosed) return false;
      emit(const LoginState.success());
      return true;
    } catch (e, st) {
      loge("Email login failed", e, st);
      if (isClosed) return false;
      emit(const LoginState.failed(reason: LoginFailedReason.unknown));
      return false;
    }
  }
}

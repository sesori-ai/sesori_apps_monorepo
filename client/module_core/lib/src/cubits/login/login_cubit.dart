import "dart:async";

import "package:bloc/bloc.dart";
import "package:http/http.dart" show ClientException;
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../platform/lifecycle_source.dart";
import "../../platform/url_launcher.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../services/installation_analytics_service.dart";
import "login_failed_reason.dart";
import "login_state.dart";

enum _LoginAnalyticsOutcome { open, terminal }

final class _LoginAttempt {
  final AuthProvider provider;
  _LoginAnalyticsOutcome analyticsOutcome = _LoginAnalyticsOutcome.open;
  _LoginAttempt({required this.provider});
}

/// Opaque ownership token for one native Apple sign-in operation.
final class AppleLoginAttempt {
  final _LoginAttempt _attempt;
  AppleLoginAttempt._({required _LoginAttempt attempt}) : _attempt = attempt;
}

class LoginCubit extends Cubit<LoginState> {
  final OAuthFlowProvider _oAuthFlowProvider;
  final UrlLauncher _urlLauncher;
  final AuthSession _authSession;
  final LifecycleSource _lifecycleSource;
  final InstallationAnalyticsService _installationAnalyticsService;
  StreamSubscription<LifecycleState>? _lifecycleSubscription;
  _LoginAttempt? _loginAttempt;
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

  LoginCubit({
    required OAuthFlowProvider oAuthFlowProvider,
    required UrlLauncher urlLauncher,
    required AuthSession authSession,
    required LifecycleSource lifecycleSource,
    required InstallationAnalyticsService installationAnalyticsService,
  }) : _oAuthFlowProvider = oAuthFlowProvider,
       _urlLauncher = urlLauncher,
       _authSession = authSession,
       _lifecycleSource = lifecycleSource,
       _installationAnalyticsService = installationAnalyticsService,
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
          });
      }
    });
  }

  @override
  Future<void> close() async {
    _loginAttempt = null;
    await _lifecycleSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAppResumed() async {
    if (_isPolling) return;
    if (state is LoginPolling || state is LoginTimeout) {
      final attempt = _currentAttempt;
      if (attempt == null) return;
      final hasActiveSession = await _oAuthFlowProvider.hasActiveOAuthSession();
      if (!_ownsAttempt(attempt: attempt) || state is! LoginPolling && state is! LoginTimeout) {
        return;
      }
      if (!hasActiveSession) {
        // A background interruption parks the flow in LoginPolling. If the
        // session has since expired/cleared, reset to idle instead of leaving
        // a permanently stuck spinner.
        if (state is LoginPolling) {
          _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.timeout);
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
        if (!_ownsAttempt(attempt: attempt)) return;
        _reportCompletedAttempt(attempt: attempt);
        emit(const LoginState.success());
      } on TimeoutException catch (e, st) {
        loge("OAuth resumed but timed out", e, st);
        if (!_ownsAttempt(attempt: attempt)) return;
        _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.timeout);
        emit(const LoginState.timeout());
      } catch (e, st) {
        if (_handlePollInterruption(error: e, attempt: attempt)) return;
        loge("OAuth resumed but failed", e, st);
        if (!_ownsAttempt(attempt: attempt)) return;
        _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.unknown);
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
  bool _handlePollInterruption({
    required Object error,
    required _LoginAttempt attempt,
  }) {
    if (!_ownsAttempt(attempt: attempt)) return false;
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
          if (_ownsAttempt(attempt: attempt)) {
            _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.unknown);
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
    final attempt = _beginAttempt(provider: provider);
    emit(const LoginState.authenticating());

    try {
      final initResponse = await _oAuthFlowProvider.startOAuthFlow(provider: provider);
      if (!_ownsAttempt(attempt: attempt)) return false;

      // Show the resumable polling UI and ARM the poll guard BEFORE launching
      // the browser. Opening the browser can suspend the app before launch()
      // returns; with _isPolling already set, a resume during that window is a
      // no-op (it won't start a second concurrent poll) — the pollForResult()
      // below owns the session. The finally resets the guard on every exit path
      // (launch failure, success, or a thrown poll error), so the outer catch's
      // _handlePollInterruption still sees _isPolling == false.
      emit(const LoginState.polling());
      _didActivePollEnterBackground = _isInBackground;
      _isPolling = true;
      try {
        logd("Opening ${provider.label} auth URL in browser");

        final launched = await _urlLauncher.launch(Uri.parse(initResponse.authUrl));
        if (!_ownsAttempt(attempt: attempt)) return false;

        if (!launched) {
          _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.launch);
          emit(const LoginState.failed(reason: LoginFailedReason.browserOpenFailed));
          return false;
        }

        await _oAuthFlowProvider.pollForResult();
      } finally {
        _isPolling = false;
      }

      if (!_ownsAttempt(attempt: attempt)) return false;
      _reportCompletedAttempt(attempt: attempt);
      emit(const LoginState.success());
      return true;
    } on TimeoutException catch (e, st) {
      loge("${provider.label} login timed out", e, st);
      if (!_ownsAttempt(attempt: attempt)) return false;
      _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.timeout);
      emit(const LoginState.timeout());
      return false;
    } catch (e, st) {
      if (_handlePollInterruption(error: e, attempt: attempt)) return false;
      loge("${provider.label} login failed", e, st);
      if (!_ownsAttempt(attempt: attempt)) return false;
      _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.unknown);
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

  void onMissingAppleIdToken({required AppleLoginAttempt attempt}) {
    final loginAttempt = _ownedOpenAppleAttempt(attempt: attempt);
    if (loginAttempt == null) return;
    _reportFailedAttempt(
      attempt: loginAttempt,
      cause: LoginAttemptFailureCause.authentication,
    );
    emit(const LoginState.failed(reason: LoginFailedReason.appleIdTokenMissing));
  }

  AppleLoginAttempt beginAppleLoginAttempt() {
    if (state is LoginPolling || state is LoginTimeout) {
      emit(const LoginState.idle());
    }
    return AppleLoginAttempt._(attempt: _beginAttempt(provider: AuthProvider.apple));
  }

  void onAppleSignInCancelled({required AppleLoginAttempt attempt}) {
    final loginAttempt = _ownedOpenAppleAttempt(attempt: attempt);
    if (loginAttempt == null) return;
    _reportFailedAttempt(attempt: loginAttempt, cause: LoginAttemptFailureCause.cancelled);
  }

  void onAppleSignInError({required AppleLoginAttempt attempt}) {
    final loginAttempt = _ownedOpenAppleAttempt(attempt: attempt);
    if (loginAttempt == null) return;
    _reportFailedAttempt(attempt: loginAttempt, cause: LoginAttemptFailureCause.unknown);
    emit(const LoginState.failed(reason: LoginFailedReason.unknown));
  }

  Future<bool> loginWithApple({
    required AppleLoginAttempt attempt,
    required String idToken,
    required String nonce,
  }) async {
    final loginAttempt = _ownedOpenAppleAttempt(attempt: attempt);
    if (loginAttempt == null) return false;
    emit(const LoginState.authenticating());

    try {
      await _authSession.loginWithApple(idToken: idToken, nonce: nonce);
      if (!_ownsAttempt(attempt: loginAttempt)) return false;
      _reportCompletedAttempt(attempt: loginAttempt);
      emit(const LoginState.success());
      return true;
    } catch (e, st) {
      loge("Apple login failed", e, st);
      if (!_ownsAttempt(attempt: loginAttempt)) return false;
      _reportFailedAttempt(attempt: loginAttempt, cause: LoginAttemptFailureCause.authentication);
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

    final attempt = _beginAttempt(provider: AuthProvider.email);
    emit(const LoginState.authenticating());

    try {
      await _authSession.loginWithEmail(email: email.trim(), password: password);
      if (!_ownsAttempt(attempt: attempt)) return false;
      _reportCompletedAttempt(attempt: attempt);
      emit(const LoginState.success());
      return true;
    } catch (e, st) {
      loge("Email login failed", e, st);
      if (!_ownsAttempt(attempt: attempt)) return false;
      _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.authentication);
      emit(const LoginState.failed(reason: LoginFailedReason.unknown));
      return false;
    }
  }

  _LoginAttempt _beginAttempt({required AuthProvider provider}) {
    final attempt = _LoginAttempt(provider: provider);
    _loginAttempt = attempt;
    _report(
      operation: _installationAnalyticsService.loginAttemptStarted(provider: provider),
      description: "login attempt start",
    );
    return attempt;
  }

  _LoginAttempt? get _currentAttempt => _loginAttempt;

  bool _ownsAttempt({required _LoginAttempt attempt}) => !isClosed && identical(_loginAttempt, attempt);

  _LoginAttempt? _ownedOpenAppleAttempt({required AppleLoginAttempt attempt}) {
    final loginAttempt = attempt._attempt;
    if (loginAttempt.provider != AuthProvider.apple || !_ownsAttempt(attempt: loginAttempt)) {
      return null;
    }
    return loginAttempt.analyticsOutcome == _LoginAnalyticsOutcome.open ? loginAttempt : null;
  }

  void _reportCompletedAttempt({required _LoginAttempt attempt}) {
    if (!_ownsAttempt(attempt: attempt)) return;
    if (attempt.analyticsOutcome != _LoginAnalyticsOutcome.open) return;
    attempt.analyticsOutcome = _LoginAnalyticsOutcome.terminal;
    _report(
      operation: _installationAnalyticsService.loginAttemptCompleted(provider: attempt.provider),
      description: "login attempt completion",
    );
  }

  void _reportFailedAttempt({
    required _LoginAttempt? attempt,
    required LoginAttemptFailureCause cause,
  }) {
    if (attempt == null || !_ownsAttempt(attempt: attempt)) return;
    if (attempt.analyticsOutcome != _LoginAnalyticsOutcome.open) return;
    attempt.analyticsOutcome = _LoginAnalyticsOutcome.terminal;
    _report(
      operation: _installationAnalyticsService.loginAttemptFailed(provider: attempt.provider, cause: cause),
      description: "login attempt failure",
    );
  }

  void _report({
    required Future<AnalyticsDeliveryResult> operation,
    required String description,
  }) {
    unawaited(
      operation.then<void>((_) {}).catchError((Object error, StackTrace stackTrace) {
        logw("Failed to report $description", error, stackTrace);
      }),
    );
  }
}

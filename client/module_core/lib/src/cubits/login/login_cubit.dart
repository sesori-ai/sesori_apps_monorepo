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
import "login_handoff.dart";
import "login_state.dart";

enum _LoginAnalyticsOutcome() {
  open,
  terminal,
}

sealed class _LoginAttempt({required final AuthProvider provider}) {
  _LoginAnalyticsOutcome analyticsOutcome = _LoginAnalyticsOutcome.open;
}

/// An attempt with no browser handoff: email, native Apple, or a browser
/// sign-in whose flow has not started yet.
final class _PendingLoginAttempt({required super.provider}) extends _LoginAttempt;

/// A browser sign-in waiting for the user; it replaces the pending attempt
/// once the flow has started.
final class _BrowserLoginAttempt({
  required super.provider,
  required var LoginHandoff handoff,
}) extends _LoginAttempt {
  /// Whether any launch of the sign-in page, first or reopened, succeeded.
  bool browserEverOpened = false;
}

/// Opaque ownership token for one native Apple sign-in operation.
final class AppleLoginAttempt._({required final _LoginAttempt _attempt});

class LoginCubit({
  required final OAuthFlowProvider _oAuthFlowProvider,
  required final UrlLauncher _urlLauncher,
  required final AuthSession _authSession,
  required final LifecycleSource _lifecycleSource,
  required final InstallationAnalyticsService _installationAnalyticsService,
}) extends Cubit<LoginState> {
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

  this : super(const LoginState.idle()) {
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
    return await super.close();
  }

  Future<void> _onAppResumed() async {
    if (_isPolling) return;
    if (state is LoginPolling || state is LoginTimeout) {
      final attempt = _currentAttempt;
      if (attempt is! _BrowserLoginAttempt) return;
      late final bool hasActiveSession;
      try {
        hasActiveSession = await _oAuthFlowProvider.hasActiveOAuthSession();
      } on Object catch (error, stackTrace) {
        loge("OAuth active-session check failed", error, stackTrace);
        if (!_ownsAttempt(attempt: attempt) || state is! LoginPolling && state is! LoginTimeout) {
          return;
        }
        _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.unknown);
        emit(const LoginState.failed(reason: LoginFailedReason.unknown));
        return;
      }
      if (!_ownsAttempt(attempt: attempt) || state is! LoginPolling && state is! LoginTimeout) {
        return;
      }
      if (!hasActiveSession) {
        // A background interruption parks the flow in LoginPolling. If the
        // session has since expired/cleared, reset to idle instead of leaving
        // a permanently stuck spinner.
        if (state is LoginPolling) {
          _reportFailedAttempt(
            attempt: attempt,
            cause: _unrecoveredCause(attempt: attempt, cause: .timeout),
          );
          emit(const LoginState.idle());
        }
        return;
      }
      if (isClosed) return;

      _didActivePollEnterBackground = _isInBackground;
      _isPolling = true;
      _emitPolling(attempt: attempt);
      try {
        final result = await _oAuthFlowProvider.resumeOAuthFlow();
        if (!_ownsAttempt(attempt: attempt)) return;
        _reportCompletedAttempt(attempt: attempt, accountStatus: result.accountStatus);
        emit(const LoginState.success());
      } catch (e, st) {
        _failOAuthAttempt(attempt: attempt, error: e, stackTrace: st, description: "Resumed OAuth login");
      } finally {
        _endPolling(attempt: attempt);
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
    if (attempt is! _BrowserLoginAttempt || !_ownsAttempt(attempt: attempt)) return false;
    if (!_isRecoverablePollInterruption(error)) return false;
    if (!_isInBackground && !_didActivePollEnterBackground) return false;
    final alreadyForeground = !_isInBackground;
    _didActivePollEnterBackground = false;
    if (isClosed) return true;
    _emitPolling(attempt: attempt);
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
    _LoginAttempt attempt = _beginAttempt(provider: provider);
    emit(const LoginState.authenticating());

    try {
      final oauth = await _oAuthFlowProvider.startOAuthFlow(provider: provider);
      if (!_ownsAttempt(attempt: attempt)) return false;
      // The waiting attempt takes over ownership; its analytics outcome is
      // still open because nothing ends an attempt while its flow starts.
      final browserAttempt = _BrowserLoginAttempt(
        provider: provider,
        handoff: LoginHandoff(provider: provider, oauth: oauth, browser: LoginBrowserLaunch.opened),
      );
      _loginAttempt = browserAttempt;
      attempt = browserAttempt;

      // Show the resumable polling UI and ARM the poll guard BEFORE launching
      // the browser. Opening the browser can suspend the app before launch()
      // returns; with _isPolling already set, a resume during that window is a
      // no-op (it won't start a second concurrent poll) — the pollForResult()
      // below owns the session. The finally resets the guard on every exit path
      // (success or a thrown poll error), so the outer catch's
      // _handlePollInterruption still sees _isPolling == false.
      _emitPolling(attempt: browserAttempt);
      _didActivePollEnterBackground = _isInBackground;
      _isPolling = true;
      late final AuthLoginResult result;
      try {
        logd("Opening ${provider.label} auth URL in browser");

        final launched = await _urlLauncher.launch(oauth.authUrl);
        if (!_ownsAttempt(attempt: attempt)) return false;

        // A failed launch keeps waiting: the sign-in page can still be opened
        // by hand or by reopening it.
        _recordLaunch(attempt: browserAttempt, launched: launched);

        result = await _oAuthFlowProvider.pollForResult();
      } finally {
        _endPolling(attempt: attempt);
      }

      if (!_ownsAttempt(attempt: attempt)) return false;
      _reportCompletedAttempt(attempt: attempt, accountStatus: result.accountStatus);
      emit(const LoginState.success());
      return true;
    } catch (e, st) {
      _failOAuthAttempt(attempt: attempt, error: e, stackTrace: st, description: "${provider.label} login");
      return false;
    }
  }

  /// Abandons the browser sign-in that is waiting for the user.
  Future<void> cancel() async {
    final attempt = _currentAttempt;
    if (attempt is! _BrowserLoginAttempt || state is! LoginPolling) return;
    _reportFailedAttempt(
      attempt: attempt,
      cause: _unrecoveredCause(attempt: attempt, cause: .cancelled),
    );
    _loginAttempt = null;
    _isPolling = false;
    // Called before any await so the flow is captured before a new one starts.
    final cancellation = _oAuthFlowProvider.cancelOAuthFlow();
    emit(const LoginState.idle());
    try {
      await cancellation;
    } catch (e, st) {
      loge("Failed to cancel the OAuth flow", e, st);
    }
  }

  /// Opens the waiting browser sign-in page again.
  Future<void> reopenBrowser() async {
    final attempt = _currentAttempt;
    if (attempt is! _BrowserLoginAttempt || state is! LoginPolling) return;
    final launched = await _urlLauncher.launch(attempt.handoff.oauth.authUrl);
    if (!_ownsAttempt(attempt: attempt) || state is! LoginPolling) return;
    _recordLaunch(attempt: attempt, launched: launched);
  }

  void _recordLaunch({required _BrowserLoginAttempt attempt, required bool launched}) {
    if (launched) attempt.browserEverOpened = true;
    final handoff = attempt.handoff;
    final browser = launched ? LoginBrowserLaunch.opened : LoginBrowserLaunch.failed;
    if (handoff.browser == browser) return;
    attempt.handoff = LoginHandoff(provider: handoff.provider, oauth: handoff.oauth, browser: browser);
    _emitPolling(attempt: attempt);
  }

  void _emitPolling({required _BrowserLoginAttempt attempt}) {
    emit(LoginState.polling(handoff: attempt.handoff));
  }

  /// Clears the poll guard unless a newer attempt (started after a cancel)
  /// now owns it.
  void _endPolling({required _LoginAttempt attempt}) {
    if (_ownsAttempt(attempt: attempt)) _isPolling = false;
  }

  /// The terminal cause of a cancelled or timed-out attempt: one whose browser
  /// never opened, on any launch, reports `launch` instead.
  LoginAttemptFailureCause _unrecoveredCause({
    required _LoginAttempt attempt,
    required LoginAttemptFailureCause cause,
  }) => switch (attempt) {
    _BrowserLoginAttempt(:final browserEverOpened) => browserEverOpened ? cause : LoginAttemptFailureCause.launch,
    _PendingLoginAttempt() => LoginAttemptFailureCause.launch,
  };

  /// Ends an OAuth attempt whose start or poll threw, unless the error is a
  /// recoverable background interruption or the attempt was superseded.
  void _failOAuthAttempt({
    required _LoginAttempt attempt,
    required Object error,
    required StackTrace stackTrace,
    required String description,
  }) {
    if (_handlePollInterruption(error: error, attempt: attempt)) return;
    if (!_ownsAttempt(attempt: attempt)) {
      // Cancelled or replaced: the error only reports the flow being abandoned.
      logd("$description ended after it was superseded", error, stackTrace);
      return;
    }
    loge("$description failed", error, stackTrace);
    switch (error) {
      case TimeoutException() || OAuthFlowExpired():
        _reportFailedAttempt(
          attempt: attempt,
          cause: _unrecoveredCause(attempt: attempt, cause: .timeout),
        );
        emit(const LoginState.timeout());
      case OAuthFlowDenied():
        _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.cancelled);
        emit(const LoginState.failed(reason: LoginFailedReason.declined));
      default:
        _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.unknown);
        emit(const LoginState.failed(reason: LoginFailedReason.unknown));
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
    final attempt = AppleLoginAttempt._(attempt: _beginAttempt(provider: AuthProvider.apple));
    emit(const LoginState.authenticating());
    return attempt;
  }

  void onAppleSignInCancelled({required AppleLoginAttempt attempt}) {
    final loginAttempt = _ownedOpenAppleAttempt(attempt: attempt);
    if (loginAttempt == null) return;
    _reportFailedAttempt(attempt: loginAttempt, cause: LoginAttemptFailureCause.cancelled);
    emit(const LoginState.idle());
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
      final result = await _authSession.loginWithApple(idToken: idToken, nonce: nonce);
      if (!_ownsAttempt(attempt: loginAttempt)) return false;
      _reportCompletedAttempt(attempt: loginAttempt, accountStatus: result.accountStatus);
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
      final result = await _authSession.loginWithEmail(email: email.trim(), password: password);
      if (!_ownsAttempt(attempt: attempt)) return false;
      _reportCompletedAttempt(attempt: attempt, accountStatus: result.accountStatus);
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
    _reportFailedAttempt(
      attempt: _loginAttempt,
      cause: LoginAttemptFailureCause.unknown,
    );
    final attempt = _PendingLoginAttempt(provider: provider);
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

  void _reportCompletedAttempt({required _LoginAttempt attempt, required AccountStatus accountStatus}) {
    if (!_ownsAttempt(attempt: attempt)) return;
    if (attempt.analyticsOutcome != _LoginAnalyticsOutcome.open) return;
    attempt.analyticsOutcome = _LoginAnalyticsOutcome.terminal;
    _report(
      operation: _installationAnalyticsService.loginAttemptCompleted(
        provider: attempt.provider,
        accountStatus: accountStatus,
      ),
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

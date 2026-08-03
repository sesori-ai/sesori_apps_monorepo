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
  bool oAuthRestartUsed = false;
  DateTime? oAuthDeadline;
  _OAuthRestartWait? _wait;
  _LoginAttempt({required this.provider});

  void cancel() => _wait?.cancel();
}

final class _OAuthRestartWait {
  final LifecycleSource lifecycleSource;
  final Duration delay;
  final DateTime deadline;
  final Completer<bool> _completion = Completer();

  _OAuthRestartWait({required this.lifecycleSource, required this.delay, required this.deadline});

  Future<bool> run() async {
    if (_completion.isCompleted) return _completion.future;
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException("OAuth authorization timed out");
    }
    final deadlineTimer = Timer(
      remaining,
      () => _completeError(
        error: TimeoutException("OAuth authorization timed out"),
        stackTrace: StackTrace.current,
      ),
    );
    Timer? delayTimer;
    StreamSubscription<LifecycleState>? subscription;

    try {
      if (delay > Duration.zero) {
        final delayCompleted = Completer<void>();
        delayTimer = Timer(delay, delayCompleted.complete);
        await Future.any<void>([
          delayCompleted.future,
          _completion.future.then<void>((_) {}),
        ]);
        if (_completion.isCompleted) return _completion.future;
      }

      if (lifecycleSource.lifecycleState == LifecycleState.resumed) {
        _complete(result: true);
      } else {
        subscription = lifecycleSource.lifecycleStateStream.listen(
          (state) {
            if (state == LifecycleState.resumed) _complete(result: true);
          },
          onError: (Object error, StackTrace stackTrace) => _completeError(error: error, stackTrace: stackTrace),
          onDone: () => _completeError(
            error: StateError("OAuth restart lifecycle stream closed unexpectedly"),
            stackTrace: StackTrace.current,
          ),
        );
        if (lifecycleSource.lifecycleState == LifecycleState.resumed) {
          _complete(result: true);
        }
      }
      return await _completion.future;
    } finally {
      deadlineTimer.cancel();
      delayTimer?.cancel();
      await subscription?.cancel();
    }
  }

  void cancel() => _complete(result: false);

  void _complete({required bool result}) {
    if (!_completion.isCompleted) {
      _completion.complete(result);
    }
  }

  void _completeError({required Object error, required StackTrace stackTrace}) {
    if (!_completion.isCompleted) {
      _completion.completeError(error, stackTrace);
    }
  }
}

/// Opaque ownership token for one native Apple sign-in operation.
final class AppleLoginAttempt {
  final _LoginAttempt _attempt;
  AppleLoginAttempt._({required _LoginAttempt attempt}) : _attempt = attempt;
}

class LoginCubit extends Cubit<LoginState> {
  static const _oAuthTimeout = Duration(minutes: 5);
  final OAuthFlowProvider _oAuthFlowProvider;
  final UrlLauncher _urlLauncher;
  final AuthSession _authSession;
  final LifecycleSource _lifecycleSource;
  final InstallationAnalyticsService _installationAnalyticsService;
  StreamSubscription<LifecycleState>? _lifecycleSubscription;
  _LoginAttempt? _loginAttempt;
  _LoginAttempt? _pollingAttempt;

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
          if (_pollingAttempt != null) {
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
    final attempt = _loginAttempt;
    _loginAttempt = null;
    _pollingAttempt = null;
    attempt?.cancel();
    await _lifecycleSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAppResumed() async {
    if (_pollingAttempt != null) return;
    if (state is LoginPolling || state is LoginTimeout) {
      final attempt = _currentAttempt;
      if (attempt == null) return;
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
          _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.timeout);
          emit(const LoginState.idle());
        }
        return;
      }
      if (isClosed) return;

      emit(const LoginState.polling());
      try {
        final completed = await _runOAuthFlow(attempt: attempt, resumeExisting: true);
        if (!completed) return;
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
      // the polling guard before `_onAppResumed` runs.
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
      final completed = await _runOAuthFlow(attempt: attempt, resumeExisting: false);
      if (!completed || !_ownsAttempt(attempt: attempt)) return false;
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
    final previousAttempt = _loginAttempt;
    _reportFailedAttempt(
      attempt: previousAttempt,
      cause: LoginAttemptFailureCause.unknown,
    );
    _loginAttempt = null;
    previousAttempt?.cancel();
    final attempt = _LoginAttempt(provider: provider);
    _loginAttempt = attempt;
    _report(
      operation: _installationAnalyticsService.loginAttemptStarted(provider: provider),
      description: "login attempt start",
    );
    return attempt;
  }

  Future<bool> _runOAuthFlow({required _LoginAttempt attempt, required bool resumeExisting}) async {
    final provider = switch (attempt.provider) {
      final OAuthProvider provider => provider,
      EmailAuthProvider() => throw StateError("OAuth session restart requires an OAuth provider"),
    };
    var resume = resumeExisting;
    _pollingAttempt = attempt;
    _didActivePollEnterBackground = _isInBackground;
    try {
      while (_ownsAttempt(attempt: attempt)) {
        try {
          if (resume) {
            resume = false;
            await _oAuthFlowProvider.resumeOAuthFlow();
          } else {
            final flowDeadline = attempt.oAuthDeadline ?? DateTime.now().add(_oAuthTimeout);
            attempt.oAuthDeadline = flowDeadline;
            final initResponse = await _oAuthFlowProvider.startOAuthFlow(
              provider: provider,
              deadline: attempt.oAuthRestartUsed ? flowDeadline : null,
            );
            if (!_ownsAttempt(attempt: attempt)) return false;
            final serverDeadline = DateTime.now().add(Duration(seconds: initResponse.expiresIn));
            final deadline = flowDeadline.isBefore(serverDeadline) ? flowDeadline : serverDeadline;
            attempt.oAuthDeadline = deadline;
            emit(const LoginState.polling());
            if (!await _waitUntilOAuthReady(
              attempt: attempt,
              delay: Duration.zero,
              deadline: deadline,
            )) {
              return false;
            }
            if (!_ownsAttempt(attempt: attempt)) return false;

            _throwIfOAuthDeadlineReached(attempt: attempt);
            _didActivePollEnterBackground = _isInBackground;
            logd("Opening ${provider.label} auth URL in browser");
            final launchBudget = deadline.difference(DateTime.now());
            if (launchBudget <= Duration.zero) {
              throw TimeoutException("OAuth authorization timed out");
            }
            final launched = await _urlLauncher
                .launch(Uri.parse(initResponse.authUrl))
                .timeout(
                  launchBudget,
                  onTimeout: () => throw TimeoutException("OAuth authorization timed out"),
                );
            if (!_ownsAttempt(attempt: attempt)) return false;
            _throwIfOAuthDeadlineReached(attempt: attempt);
            if (!launched) {
              _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.launch);
              emit(const LoginState.failed(reason: LoginFailedReason.browserOpenFailed));
              return false;
            }

            await _oAuthFlowProvider.pollForResult();
          }
          return _ownsAttempt(attempt: attempt);
        } on OAuthSessionRestartRequiredException catch (error, stackTrace) {
          if (!_ownsAttempt(attempt: attempt)) return false;
          if (attempt.oAuthRestartUsed) {
            _throwIfOAuthDeadlineReached(attempt: attempt);
            Error.throwWithStackTrace(error, stackTrace);
          }
          attempt.oAuthRestartUsed = true;
          attempt.oAuthDeadline = error.deadline;
          if (!await _waitUntilOAuthReady(
            attempt: attempt,
            delay: error.restartAfter,
            deadline: error.deadline,
          )) {
            return false;
          }
          resume = false;
        }
      }
      return false;
    } finally {
      if (identical(_pollingAttempt, attempt)) {
        _pollingAttempt = null;
      }
    }
  }

  void _throwIfOAuthDeadlineReached({required _LoginAttempt attempt}) {
    final deadline = attempt.oAuthDeadline;
    if (deadline != null && !DateTime.now().isBefore(deadline)) {
      throw TimeoutException("OAuth authorization timed out");
    }
  }

  Future<bool> _waitUntilOAuthReady({
    required _LoginAttempt attempt,
    required Duration delay,
    required DateTime deadline,
  }) async {
    var currentDelay = delay;
    while (true) {
      final wait = _OAuthRestartWait(
        lifecycleSource: _lifecycleSource,
        delay: currentDelay,
        deadline: deadline,
      );
      attempt._wait = wait;
      final ready = await wait.run().whenComplete(() {
        if (identical(attempt._wait, wait)) attempt._wait = null;
      });
      if (!_ownsAttempt(attempt: attempt) || !ready) return false;
      _throwIfOAuthDeadlineReached(attempt: attempt);
      if (_lifecycleSource.lifecycleState == LifecycleState.resumed) return true;
      currentDelay = Duration.zero;
    }
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

import "dart:async";

import "package:bloc/bloc.dart";
import "package:http/http.dart" show ClientException;
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
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
  OAuthRestartWait? _wait;
  bool _cancelled = false;
  _LoginAttempt({required this.provider});
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _wait?.cancel();
    _wait = null;
  }
}

final class _UnexpectedOAuthRestartLifecycleDone implements Exception {
  const _UnexpectedOAuthRestartLifecycleDone();
  @override
  String toString() => "OAuth restart lifecycle stream closed unexpectedly";
}

enum OAuthRestartWaitResult { ready, cancelled, deadline }

@visibleForTesting
final class OAuthRestartWaitCombinedFailure implements Exception {
  final AsyncError operationFailure;
  final AsyncError cleanupFailure;
  const OAuthRestartWaitCombinedFailure({required this.operationFailure, required this.cleanupFailure});
}

@visibleForTesting
final class OAuthRestartWait {
  final ValueStream<LifecycleState> lifecycle;
  final Duration delay;
  final DateTime deadline;
  final Completer<OAuthRestartWaitResult> _completion = Completer();
  Timer? _deadlineTimer;
  Timer? _delayTimer;
  // ignore: cancel_subscriptions, _finish always cancels the owned subscription
  StreamSubscription<LifecycleState>? _subscription;
  bool _finishing = false;
  OAuthRestartWait({required this.lifecycle, required this.delay, required this.deadline});
  Future<OAuthRestartWaitResult> run() {
    if (_finishing) return _completion.future;
    final remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      _deadlineTimer = Timer(remaining, () => _resolve(OAuthRestartWaitResult.deadline));
      _delayTimer = delay > Duration.zero ? Timer(delay, _listenForResume) : null;
      if (_delayTimer == null) _listenForResume();
    } else {
      _resolve(OAuthRestartWaitResult.deadline);
    }
    return _completion.future;
  }

  void cancel() => _resolve(OAuthRestartWaitResult.cancelled);
  void _listenForResume() {
    if (!DateTime.now().isBefore(deadline)) {
      _resolve(OAuthRestartWaitResult.deadline);
      return;
    }
    if (lifecycle.value == LifecycleState.resumed) {
      _resolve(OAuthRestartWaitResult.ready);
      return;
    }
    _subscription = lifecycle.listen(_onLifecycleState, onError: _onLifecycleError, onDone: _onLifecycleDone);
    if (lifecycle.value == LifecycleState.resumed) _resolve(OAuthRestartWaitResult.ready);
  }

  void _onLifecycleState(LifecycleState state) {
    if (state == LifecycleState.resumed) scheduleMicrotask(() => _resolve(OAuthRestartWaitResult.ready));
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, Stream.listen callback signature
  void _onLifecycleError(Object error, StackTrace stackTrace) =>
      scheduleMicrotask(() => _fail(error: error, stackTrace: stackTrace));
  void _onLifecycleDone() => scheduleMicrotask(
    () => _fail(error: const _UnexpectedOAuthRestartLifecycleDone(), stackTrace: StackTrace.current),
  );
  void _resolve(OAuthRestartWaitResult result) => unawaited(_finish(result: result, operationFailure: null));
  void _fail({required Object error, required StackTrace stackTrace}) =>
      unawaited(_finish(result: null, operationFailure: AsyncError(error, stackTrace)));
  Future<void> _finish({
    required OAuthRestartWaitResult? result,
    required AsyncError? operationFailure,
  }) async {
    if (_finishing) return;
    _finishing = true;
    _deadlineTimer?.cancel();
    _delayTimer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    AsyncError? cleanupFailure;
    try {
      await subscription?.cancel();
    } on Object catch (error, stackTrace) {
      cleanupFailure = AsyncError(error, stackTrace);
    }
    if (operationFailure != null) {
      final error = cleanupFailure == null
          ? operationFailure.error
          : OAuthRestartWaitCombinedFailure(operationFailure: operationFailure, cleanupFailure: cleanupFailure);
      _completion.completeError(error, operationFailure.stackTrace);
    } else if (cleanupFailure != null) {
      _completion.completeError(cleanupFailure.error, cleanupFailure.stackTrace);
    } else if (result != null) {
      _completion.complete(result);
    }
  }
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

      _didActivePollEnterBackground = _isInBackground;
      _pollingAttempt = attempt;
      emit(const LoginState.polling());
      try {
        try {
          await _oAuthFlowProvider.resumeOAuthFlow();
        } on OAuthSessionRestartRequiredException catch (error, stackTrace) {
          final restarted = await _restartOAuthFlow(
            attempt: attempt,
            exception: error,
            stackTrace: stackTrace,
          );
          if (!restarted) return;
        }
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
        if (identical(_pollingAttempt, attempt)) {
          _pollingAttempt = null;
        }
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
      final AuthInitResponse initResponse;
      try {
        initResponse = await _oAuthFlowProvider.startOAuthFlow(provider: provider, deadline: null);
      } on OAuthSessionRestartRequiredException catch (error, stackTrace) {
        _pollingAttempt = attempt;
        try {
          final restarted = await _restartOAuthFlow(
            attempt: attempt,
            exception: error,
            stackTrace: stackTrace,
          );
          if (!restarted) return false;
        } finally {
          if (identical(_pollingAttempt, attempt)) {
            _pollingAttempt = null;
          }
        }
        if (!_ownsAttempt(attempt: attempt)) return false;
        _reportCompletedAttempt(attempt: attempt);
        emit(const LoginState.success());
        return true;
      }
      if (!_ownsAttempt(attempt: attempt)) return false;

      // Show the resumable polling UI and ARM the poll guard BEFORE launching
      // the browser. Opening the browser can suspend the app before launch()
      // returns; with the polling guard already set, a resume during that window is a
      // no-op (it won't start a second concurrent poll) — the pollForResult()
      // below owns the session. The finally resets the guard on every exit path
      // (launch failure, success, or a thrown poll error), so the outer catch's
      // _handlePollInterruption still sees the guard released.
      emit(const LoginState.polling());
      _didActivePollEnterBackground = _isInBackground;
      _pollingAttempt = attempt;
      try {
        logd("Opening ${provider.label} auth URL in browser");

        final launched = await _urlLauncher.launch(Uri.parse(initResponse.authUrl));
        if (!_ownsAttempt(attempt: attempt)) return false;

        if (!launched) {
          _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.launch);
          emit(const LoginState.failed(reason: LoginFailedReason.browserOpenFailed));
          return false;
        }

        try {
          await _oAuthFlowProvider.pollForResult();
        } on OAuthSessionRestartRequiredException catch (error, stackTrace) {
          final restarted = await _restartOAuthFlow(
            attempt: attempt,
            exception: error,
            stackTrace: stackTrace,
          );
          if (!restarted) return false;
        }
      } finally {
        if (identical(_pollingAttempt, attempt)) {
          _pollingAttempt = null;
        }
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

  Future<bool> _restartOAuthFlow({
    required _LoginAttempt attempt,
    required OAuthSessionRestartRequiredException exception,
    required StackTrace stackTrace,
  }) async {
    final provider = switch (attempt.provider) {
      final OAuthProvider provider => provider,
      EmailAuthProvider() => throw StateError("OAuth session restart requires an OAuth provider"),
    };
    if (attempt.oAuthRestartUsed) {
      _throwIfOAuthDeadlineReached(attempt: attempt);
      Error.throwWithStackTrace(exception, stackTrace);
    }
    attempt.oAuthRestartUsed = true;
    attempt.oAuthDeadline = exception.deadline;
    final deadline = exception.deadline;

    if (!await _waitUntilOAuthRestartReady(
      attempt: attempt,
      delay: exception.restartAfter,
      deadline: deadline,
    )) {
      return false;
    }

    final initResponse = await _beforeOAuthDeadline(
      deadline: deadline,
      operation: () => _oAuthFlowProvider.startOAuthFlow(
        provider: provider,
        deadline: deadline,
      ),
    );
    if (!_ownsAttempt(attempt: attempt)) return false;
    if (!await _waitUntilOAuthRestartReady(attempt: attempt, delay: Duration.zero, deadline: deadline)) {
      return false;
    }

    _didActivePollEnterBackground = _isInBackground;
    emit(const LoginState.polling());
    logd("Opening ${provider.label} auth URL in browser after OAuth session restart");
    final launched = await _beforeOAuthDeadline(
      deadline: deadline,
      operation: () => _urlLauncher.launch(Uri.parse(initResponse.authUrl)),
    );
    if (!_ownsAttempt(attempt: attempt)) return false;
    _throwIfOAuthDeadlineReached(attempt: attempt);
    if (!launched) {
      _reportFailedAttempt(attempt: attempt, cause: LoginAttemptFailureCause.launch);
      emit(const LoginState.failed(reason: LoginFailedReason.browserOpenFailed));
      return false;
    }

    await _oAuthFlowProvider.pollForResult();
    if (!_ownsAttempt(attempt: attempt)) return false;
    return true;
  }

  Future<T> _beforeOAuthDeadline<T>({
    required DateTime deadline,
    required Future<T> Function() operation,
  }) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return Future<T>.error(TimeoutException("OAuth authorization timed out"));
    }

    return operation().timeout(
      remaining,
      onTimeout: () => throw TimeoutException("OAuth authorization timed out"),
    );
  }

  void _throwIfOAuthDeadlineReached({required _LoginAttempt attempt}) {
    final deadline = attempt.oAuthDeadline;
    if (deadline != null && !DateTime.now().isBefore(deadline)) {
      throw TimeoutException("OAuth authorization timed out");
    }
  }

  Future<bool> _waitUntilOAuthRestartReady({
    required _LoginAttempt attempt,
    required Duration delay,
    required DateTime deadline,
  }) async {
    var currentDelay = delay;
    while (true) {
      final wait = OAuthRestartWait(
        lifecycle: _lifecycleSource.lifecycleStateStream,
        delay: currentDelay,
        deadline: deadline,
      );
      attempt._wait = wait;
      if (attempt._cancelled) wait.cancel();
      final result = await wait.run().whenComplete(() {
        if (identical(attempt._wait, wait)) attempt._wait = null;
      });
      if (!_ownsAttempt(attempt: attempt) || result == OAuthRestartWaitResult.cancelled) return false;
      if (result == OAuthRestartWaitResult.deadline) throw TimeoutException("OAuth authorization timed out");
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

import "dart:async";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show BridgeSupervisedExitCode;

import "../foundation/control_channel_server.dart";
import "../foundation/platform/bridge_executable_path_resolver.dart";
import "../repositories/bridge_process_repository.dart";
import "../trackers/bridge_process_log_tracker.dart";
import "../trackers/bridge_status_tracker.dart";
import "bridge_process_state.dart";

/// Reports a lifecycle warning without coupling tests to the global logger.
@visibleForTesting
typedef BridgeProcessWarningReporter = void Function({
  required String message,
  required Object error,
  required StackTrace stackTrace,
});

/// Layer-3 owner of authenticated helper spawn, restart policy, and teardown.
///
/// It coordinates only lower layers: the process repository owns every raw
/// process operation and the atomic expected-stop marker; the log tracker owns
/// child-pipe draining; the control server owns the per-spawn secret and
/// socket. Manual lifecycle actions supersede delayed policy work, so an old
/// retry can never create a second helper after Off or an explicit retry.
@lazySingleton
class BridgeProcessService.forTesting({
  required final BridgeProcessRepository _repository,
  required final BridgeProcessLogTracker _logTracker,
  required final BridgeStatusTracker _statusTracker,
  required final ControlChannelServer _controlChannelServer,
  required final AuthSession _authSession,
  required final BridgeExecutablePathResolver _executablePathResolver,
  required final List<Duration> _crashBackoffDelays,
  required final Duration _stableRuntime,
  required final int _recentLogCount,
  required final DateTime Function() _now,
  required final BridgeProcessWarningReporter _reportWarning,
}) {
  new({
    required BridgeProcessRepository repository,
    required BridgeProcessLogTracker logTracker,
    required BridgeStatusTracker statusTracker,
    required ControlChannelServer controlChannelServer,
    required AuthSession authSession,
    required BridgeExecutablePathResolver executablePathResolver,
  }) : this.forTesting(
         repository: repository,
         logTracker: logTracker,
         statusTracker: statusTracker,
         controlChannelServer: controlChannelServer,
         authSession: authSession,
         executablePathResolver: executablePathResolver,
         crashBackoffDelays: defaultCrashBackoffDelays,
         stableRuntime: defaultStableRuntime,
         recentLogCount: defaultRecentLogCount,
         now: DateTime.now,
         reportWarning: _logWarning,
       );

  @visibleForTesting
  this
    : assert(!_stableRuntime.isNegative, "stableRuntime must not be negative"),
      assert(_recentLogCount > 0, "recentLogCount must be positive"),
      assert(
        !_crashBackoffDelays.any((delay) => delay.isNegative),
        "crashBackoffDelays must not contain negative durations",
      ) {
    _lastObservedAuthState = _authSession.currentState;
    _exitSubscription = _repository.exits.listen(
      _onExit,
      // ignore: no_slop_linter/prefer_required_named_parameters, Stream.listen error callbacks are positional
      onError: (Object error, StackTrace stackTrace) => _onExitError(error: error, stackTrace: stackTrace),
    );
    _authSubscription = _authSession.authStateStream.listen(
      (state) => _onAuthStateChanged(state: state),
    );
    _helperStatusSubscription = _statusTracker.statusStream
        .map((status) => status.helperOnline)
        .distinct()
        .listen((connected) => _onHelperConnectionChanged(connected: connected));
  }

  static const List<Duration> defaultCrashBackoffDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];
  static const Duration defaultStableRuntime = Duration(minutes: 5);
  static const int defaultRecentLogCount = 20;

  final BehaviorSubject<BridgeProcessState> _states = BehaviorSubject<BridgeProcessState>.seeded(
    const BridgeProcessStopped(),
  );
  late final StreamSubscription<BridgeProcessExit> _exitSubscription;
  late final StreamSubscription<AuthState> _authSubscription;
  late final StreamSubscription<bool> _helperStatusSubscription;

  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  Future<void>? _exitCleanup;
  Timer? _retryTimer;
  int _crashCount = 0;
  int _lifecycleGeneration = 0;
  int _successfulAuthenticationGeneration = 0;
  int _authenticationGenerationAtSpawn = 0;
  late AuthState _lastObservedAuthState;
  BridgeProcessExit? _pendingStartupExit;
  int? _activePid;
  DateTime? _healthySince;
  bool _startupExitPolicyClaimed = false;
  bool _disposed = false;
  BridgeProcessDesiredState _desiredState = BridgeProcessDesiredState.off;

  ValueStream<BridgeProcessState> get states => _states.stream;

  BridgeProcessState get state => _states.value;

  BridgeProcessDesiredState get desiredState => _desiredState;

  /// Requests On now. A signed-out request remains desired On and resumes only
  /// after the auth session emits a successful sign-in.
  Future<void> start() {
    _ensureNotDisposed();
    _beginManualAction(desiredState: BridgeProcessDesiredState.on);
    return _requestStart();
  }

  /// Requests Off, cancels any delayed retry, and expected-stops the child.
  Future<void> stop() {
    _ensureNotDisposed();
    _beginManualAction(desiredState: BridgeProcessDesiredState.off);
    return _requestStop();
  }

  void _beginManualAction({required BridgeProcessDesiredState desiredState}) {
    _lifecycleGeneration++;
    _desiredState = desiredState;
    _crashCount = 0;
    _cancelRetry();
  }

  Future<void> _requestStart() {
    final Future<void>? existing = _startFuture;
    if (existing != null) {
      return existing;
    }
    final Future<void> rawOperation = _start();
    late final Future<void> operation;
    operation = rawOperation.whenComplete(() {
      if (identical(_startFuture, operation)) {
        _startFuture = null;
      }
    });
    _startFuture = operation;
    return operation;
  }

  Future<void> _start() async {
    final Future<void>? pendingStop = _stopFuture;
    if (pendingStop != null) {
      await pendingStop;
    }
    final Future<void>? pendingExitCleanup = _exitCleanup;
    if (pendingExitCleanup != null) {
      await pendingExitCleanup;
    }

    if (_desiredState == BridgeProcessDesiredState.off || _disposed) {
      _publish(const BridgeProcessStopped());
      return;
    }
    final int? activePid = _activePid;
    if (activePid != null) {
      _publish(BridgeProcessRunning(pid: activePid));
      return;
    }
    if (_authSession.currentState is! AuthAuthenticated) {
      _publish(const BridgeProcessLoginRequired());
      return;
    }

    _pendingStartupExit = null;
    _startupExitPolicyClaimed = false;
    _publish(const BridgeProcessStarting());
    bool controlStartAttempted = false;
    bool childCreated = false;
    try {
      controlStartAttempted = true;
      await _controlChannelServer.start();
      _throwIfStartCancelled();

      final BridgeProcessStreams streams = await _repository.spawn(
        executable: _executablePathResolver.resolve(),
        arguments: <String>["--control-url", _controlChannelServer.url.toString()],
        workingDirectory: null,
        environment: null,
      );
      childCreated = true;
      _activePid = streams.pid;
      _authenticationGenerationAtSpawn = _successfulAuthenticationGeneration;
      _healthySince = null;
      final BridgeProcessExit? pendingStartupExit = _pendingStartupExit;
      _pendingStartupExit = null;
      if (pendingStartupExit?.pid == streams.pid) {
        _beginExitCleanup(exit: pendingStartupExit);
        throw BridgeProcessExitedDuringStartException(pid: streams.pid);
      }
      _throwIfStartCannotContinue(pid: streams.pid);

      await _logTracker.attach(stdout: streams.stdout, stderr: streams.stderr);
      _throwIfStartCannotContinue(pid: streams.pid);
      streams.stdin.writeln(_controlChannelServer.secret);
      await streams.stdin.flush();
      _throwIfStartCannotContinue(pid: streams.pid);

      _publish(BridgeProcessRunning(pid: streams.pid));
    } on _BridgeProcessStartCancelled {
      await _cleanUpFailedStart(
        controlStartAttempted: controlStartAttempted,
        childCreated: childCreated,
      );
      _publish(_stateAfterStartCleanup());
    } on BridgeProcessExitedDuringStartException {
      await _cleanUpFailedStart(
        controlStartAttempted: controlStartAttempted,
        childCreated: childCreated,
      );
      _pendingStartupExit = null;
      if (!_startupExitPolicyClaimed) {
        _scheduleCrashRetry(
          exitCode: null,
          generation: _lifecycleGeneration,
          source: _BridgeCrashSource.automaticStart,
        );
      }
      // A claimed repository exit already owns its deliberate/crash policy;
      // otherwise the startup fallback above prevents desired On from stalling.
      rethrow;
    } on Object {
      await _cleanUpFailedStart(
        controlStartAttempted: controlStartAttempted,
        childCreated: childCreated,
      );
      _publish(_stateAfterStartCleanup());
      rethrow;
    }
  }

  BridgeProcessState _stateAfterStartCleanup() {
    if (!_repository.isRunning) {
      return const BridgeProcessStopped();
    }
    final int? pid = _repository.activePid;
    if (pid == null) {
      throw StateError("BridgeProcessRepository reported a running process without a PID");
    }
    return BridgeProcessStopping(pid: pid);
  }

  void _throwIfStartCancelled() {
    if (_desiredState == BridgeProcessDesiredState.off || _disposed) {
      throw const _BridgeProcessStartCancelled();
    }
  }

  void _throwIfStartCannotContinue({required int pid}) {
    _throwIfStartCancelled();
    if (_activePid != pid || !_repository.isRunning) {
      throw BridgeProcessExitedDuringStartException(pid: pid);
    }
  }

  Future<void> _requestStop() {
    final Future<void>? existing = _stopFuture;
    if (existing != null) {
      return existing;
    }
    final Future<void> operation = _stop();
    _stopFuture = operation;
    unawaited(_clearStopWhenComplete(operation: operation));
    return operation;
  }

  Future<void> _clearStopWhenComplete({required Future<void> operation}) async {
    try {
      await operation;
    } on Object {
      // The original future retains the error for its caller. This observer
      // only releases the serialized-operation slot.
    } finally {
      if (identical(_stopFuture, operation)) {
        _stopFuture = null;
      }
    }
  }

  Future<void> _stop() async {
    final Future<void>? pendingStart = _startFuture;
    if (pendingStart != null) {
      try {
        await pendingStart;
      } on Object {
        // Startup already rolled back its own partial resources. Stop still
        // completes the desired-Off transition.
      }
    }

    final int? pid = _activePid ?? _repository.activePid;
    if (pid != null) {
      _publish(BridgeProcessStopping(pid: pid));
    }
    try {
      await _repository.stopExpected();
    } on Object {
      if (_repository.isRunning) {
        final int? recoveredPid = _repository.activePid ?? pid;
        if (recoveredPid != null) {
          _publish(BridgeProcessRunning(pid: recoveredPid));
        }
      }
      rethrow;
    }

    _activePid = null;
    _clearRunHealth();
    final Future<void>? pendingExitCleanup = _exitCleanup;
    if (pendingExitCleanup != null) {
      await pendingExitCleanup;
    }
    await _controlChannelServer.stop();
    _publish(const BridgeProcessStopped());
  }

  void _onExit(BridgeProcessExit exit) {
    if (_activePid != exit.pid) {
      if (_activePid == null && state is BridgeProcessStarting) {
        _pendingStartupExit = exit;
      }
      return;
    }
    _beginExitCleanup(exit: exit);
  }

  void _onExitError({required Object error, required StackTrace stackTrace}) {
    _reportWarning(
      message: "Bridge process exit observation failed",
      error: error,
      stackTrace: stackTrace,
    );
    if (_activePid == null) {
      return;
    }
    _beginExitCleanup(exit: null);
  }

  void _beginExitCleanup({required BridgeProcessExit? exit}) {
    if (state is BridgeProcessStarting) {
      _startupExitPolicyClaimed = true;
    }
    _activePid = null;
    final bool stableRun = _wasStableRun();
    final int authenticationGenerationAtSpawn = _authenticationGenerationAtSpawn;
    _clearRunHealth();
    final int generation = _lifecycleGeneration;
    final Future<void> cleanup = _stopControlServerAfterExit();
    _exitCleanup = cleanup;
    unawaited(
      _finishExitCleanup(
        cleanup: cleanup,
        exit: exit,
        stableRun: stableRun,
        generation: generation,
        authenticationGenerationAtSpawn: authenticationGenerationAtSpawn,
      ),
    );
  }

  Future<void> _finishExitCleanup({
    required Future<void> cleanup,
    required BridgeProcessExit? exit,
    required bool stableRun,
    required int generation,
    required int authenticationGenerationAtSpawn,
  }) async {
    await cleanup;
    if (identical(_exitCleanup, cleanup)) {
      _exitCleanup = null;
    }
    if (_disposed || generation != _lifecycleGeneration) {
      return;
    }
    _applyExitPolicy(
      exit: exit,
      stableRun: stableRun,
      generation: generation,
      authenticationGenerationAtSpawn: authenticationGenerationAtSpawn,
    );
  }

  Future<void> _stopControlServerAfterExit() async {
    try {
      await _controlChannelServer.stop();
    } on Object catch (error, stackTrace) {
      _reportWarning(
        message: "Failed to stop the bridge control server after process exit",
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _applyExitPolicy({
    required BridgeProcessExit? exit,
    required bool stableRun,
    required int generation,
    required int authenticationGenerationAtSpawn,
  }) {
    if (stableRun) {
      _crashCount = 0;
    }
    if (_desiredState == BridgeProcessDesiredState.off || (exit?.expected ?? false)) {
      _publish(const BridgeProcessStopped());
      return;
    }

    final int? exitCode = exit?.exitCode;
    if (exitCode == null) {
      _scheduleCrashRetry(
        exitCode: null,
        generation: generation,
        source: _BridgeCrashSource.exitObservation,
      );
      return;
    }

    switch (BridgeSupervisedExitCode.fromCode(code: exitCode)) {
      case BridgeSupervisedExitCode.cleanStop:
        _desiredState = BridgeProcessDesiredState.off;
        _crashCount = 0;
        _publish(const BridgeProcessStopped());
        return;
      case BridgeSupervisedExitCode.restart:
        _restartAutomaticallyAfterCurrentStart(
          generation: generation,
          context: "Bridge restart after supervised restart exit",
        );
        return;
      case BridgeSupervisedExitCode.authRequired:
        _crashCount = 0;
        _publish(const BridgeProcessLoginRequired());
        if (_authSession.currentState is AuthAuthenticated &&
            _successfulAuthenticationGeneration > authenticationGenerationAtSpawn) {
          _restartAutomaticallyAfterCurrentStart(
            generation: generation,
            context: "Bridge start after authentication completed while the prior helper was exiting",
          );
        }
        return;
      case BridgeSupervisedExitCode.bridgeContention:
        _crashCount = 0;
        _publish(const BridgeProcessContention());
        return;
      case BridgeSupervisedExitCode.controlChannelLost || null:
        _scheduleCrashRetry(
          exitCode: exitCode,
          generation: generation,
          source: _BridgeCrashSource.processExit,
        );
        return;
    }
  }

  void _scheduleCrashRetry({
    required int? exitCode,
    required int generation,
    required _BridgeCrashSource source,
  }) {
    if (_disposed || generation != _lifecycleGeneration || _desiredState == BridgeProcessDesiredState.off) {
      return;
    }
    _crashCount++;
    if (_crashCount > _crashBackoffDelays.length) {
      final List<BridgeProcessLogEntry> snapshot = _logTracker.snapshot;
      final int firstRecentIndex = snapshot.length > _recentLogCount ? snapshot.length - _recentLogCount : 0;
      _publish(
        BridgeProcessCrashGiveUp(
          exitCode: exitCode,
          crashCount: _crashCount,
          recentLogs: snapshot.sublist(firstRecentIndex),
        ),
      );
      return;
    }

    final Duration delay = _crashBackoffDelays[_crashCount - 1];
    _publish(
      BridgeProcessCrashRetryScheduled(
        exitCode: exitCode,
        crashCount: _crashCount,
        delay: delay,
      ),
    );
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_disposed || generation != _lifecycleGeneration || _desiredState == BridgeProcessDesiredState.off) {
        return;
      }
      _restartAutomatically(
        generation: generation,
        context: source.retryContext,
      );
    });
  }

  void _restartAutomaticallyAfterCurrentStart({required int generation, required String context}) {
    final Future<void>? currentStart = _startFuture;
    if (currentStart == null) {
      _restartAutomatically(generation: generation, context: context);
      return;
    }
    unawaited(
      _restartWhenCurrentStartCompletes(
        currentStart: currentStart,
        generation: generation,
        context: context,
      ),
    );
  }

  Future<void> _restartWhenCurrentStartCompletes({
    required Future<void> currentStart,
    required int generation,
    required String context,
  }) async {
    try {
      await currentStart;
    } on Object {
      // The start's caller retains its outcome. Restart intent is independent
      // and must wait until that serialized-operation slot has been released.
    }
    _restartAutomatically(generation: generation, context: context);
  }

  void _restartAutomatically({required int generation, required String context}) {
    if (_disposed || generation != _lifecycleGeneration || _desiredState == BridgeProcessDesiredState.off) {
      return;
    }
    unawaited(
      _observeAutomaticStart(
        operation: _requestStart(),
        generation: generation,
        context: context,
      ),
    );
  }

  Future<void> _observeAutomaticStart({
    required Future<void> operation,
    required int generation,
    required String context,
  }) async {
    try {
      await operation;
    } on BridgeProcessExitedDuringStartException {
      // The repository exit stream already owns this child and schedules its
      // one policy action. Counting the same early exit here would consume two
      // crash-budget entries and leave two retry timers.
      return;
    } on Object catch (error, stackTrace) {
      _reportWarning(message: context, error: error, stackTrace: stackTrace);
      if (!_repository.isRunning && _activePid == null) {
        _scheduleCrashRetry(
          exitCode: null,
          generation: generation,
          source: _BridgeCrashSource.automaticStart,
        );
      }
    }
  }

  void _onAuthStateChanged({required AuthState state}) {
    final bool wasAuthenticated = _lastObservedAuthState is AuthAuthenticated;
    _lastObservedAuthState = state;
    if (state is AuthAuthenticated && !wasAuthenticated) {
      _successfulAuthenticationGeneration++;
    }
    if (state is! AuthAuthenticated ||
        _disposed ||
        _desiredState == BridgeProcessDesiredState.off ||
        this.state is! BridgeProcessLoginRequired) {
      return;
    }
    _crashCount = 0;
    _restartAutomaticallyAfterCurrentStart(
      generation: _lifecycleGeneration,
      context: "Bridge start after successful authentication",
    );
  }

  void _onHelperConnectionChanged({required bool connected}) {
    if (!connected) {
      _healthySince = null;
      return;
    }
    if (_activePid != null) {
      _healthySince ??= _now();
    }
  }

  bool _wasStableRun() {
    final DateTime? healthySince = _healthySince;
    if (healthySince == null) {
      return false;
    }
    final Duration healthyRuntime = _now().difference(healthySince);
    return !healthyRuntime.isNegative && healthyRuntime >= _stableRuntime;
  }

  void _clearRunHealth() {
    _authenticationGenerationAtSpawn = 0;
    _healthySince = null;
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> _cleanUpFailedStart({
    required bool controlStartAttempted,
    required bool childCreated,
  }) async {
    if (childCreated) {
      try {
        await _repository.stopExpected();
      } on Object catch (error, stackTrace) {
        _reportWarning(
          message: "Failed to stop a partially started bridge process",
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (controlStartAttempted) {
      try {
        await _controlChannelServer.stop();
      } on Object catch (error, stackTrace) {
        _reportWarning(
          message: "Failed to stop the control server after bridge startup failed",
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (!_repository.isRunning) {
      _activePid = null;
      _clearRunHealth();
    }
  }

  void _publish(BridgeProcessState state) {
    if (!_states.isClosed) {
      _states.add(state);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError("BridgeProcessService is disposed");
    }
  }

  static void _logWarning({
    required String message,
    required Object error,
    required StackTrace stackTrace,
  }) => logw(message, error, stackTrace);

  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    try {
      await stop();
    } finally {
      _disposed = true;
      _cancelRetry();
      try {
        await _controlChannelServer.stop();
      } on Object catch (error, stackTrace) {
        // Disposal must preserve a stopExpected failure while still revoking
        // the authenticated local socket as best effort.
        _reportWarning(
          message: "Failed to stop the bridge control server during disposal",
          error: error,
          stackTrace: stackTrace,
        );
      }
      await _authSubscription.cancel();
      await _helperStatusSubscription.cancel();
      await _exitSubscription.cancel();
      await _states.close();
    }
  }
}

final class const _BridgeProcessStartCancelled() implements Exception;

enum _BridgeCrashSource({required final String retryContext}) {
  processExit(retryContext: "Bridge restart after unexpected exit"),
  exitObservation(retryContext: "Bridge restart after exit observer error"),
  automaticStart(retryContext: "Bridge retry after automatic startup failure");
}

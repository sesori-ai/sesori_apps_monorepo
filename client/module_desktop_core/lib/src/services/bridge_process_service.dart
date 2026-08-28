import "dart:async";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/control_channel_server.dart";
import "../foundation/platform/bridge_executable_path_resolver.dart";
import "../repositories/bridge_process_repository.dart";
import "../trackers/bridge_process_log_tracker.dart";
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
    required ControlChannelServer controlChannelServer,
    required AuthSession authSession,
    required BridgeExecutablePathResolver executablePathResolver,
  }) : this.forTesting(
         repository: repository,
         logTracker: logTracker,
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
    _exitSubscription = _repository.exits.listen(
      _onExit,
      // ignore: no_slop_linter/prefer_required_named_parameters, Stream.listen error callbacks are positional
      onError: (Object error, StackTrace stackTrace) => _onExitError(error: error, stackTrace: stackTrace),
    );
    _authSubscription = _authSession.authStateStream.listen(
      (state) => _onAuthStateChanged(state: state),
    );
    _helperConnectionSubscription = _controlChannelServer.helperConnectionStream.listen(
      (connected) => _onHelperConnectionChanged(connected: connected),
    );
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
  late final StreamSubscription<bool> _helperConnectionSubscription;

  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  Future<void>? _exitCleanup;
  Timer? _retryTimer;
  int _crashCount = 0;
  int _lifecycleGeneration = 0;
  int? _activePid;
  DateTime? _healthySince;
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
    final Future<void> operation = _start();
    _startFuture = operation;
    unawaited(_clearStartWhenComplete(operation: operation));
    return operation;
  }

  Future<void> _clearStartWhenComplete({required Future<void> operation}) async {
    try {
      await operation;
    } on Object {
      // The original future retains the error for its caller. This observer
      // only releases the serialized-operation slot.
    } finally {
      if (identical(_startFuture, operation)) {
        _startFuture = null;
      }
    }
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
      _healthySince = null;
      _throwIfStartCancelled();

      await _logTracker.attach(stdout: streams.stdout, stderr: streams.stderr);
      _throwIfStartCancelled();
      streams.stdin.writeln(_controlChannelServer.secret);
      await streams.stdin.flush();
      _throwIfStartCancelled();

      if (_activePid != streams.pid || !_repository.isRunning) {
        throw BridgeProcessExitedDuringStartException(pid: streams.pid);
      }
      _publish(BridgeProcessRunning(pid: streams.pid));
    } on _BridgeProcessStartCancelled {
      await _cleanUpFailedStart(
        controlStartAttempted: controlStartAttempted,
        childCreated: childCreated,
      );
      _publish(_repository.isRunning ? BridgeProcessStopping(pid: _activePid) : const BridgeProcessStopped());
    } on Object {
      await _cleanUpFailedStart(
        controlStartAttempted: controlStartAttempted,
        childCreated: childCreated,
      );
      _publish(_repository.isRunning ? BridgeProcessStopping(pid: _activePid) : const BridgeProcessStopped());
      rethrow;
    }
  }

  void _throwIfStartCancelled() {
    if (_desiredState == BridgeProcessDesiredState.off || _disposed) {
      throw const _BridgeProcessStartCancelled();
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

    final int? pid = _activePid;
    if (pid != null || _repository.isRunning) {
      _publish(BridgeProcessStopping(pid: pid ?? _repository.activePid));
    }
    try {
      await _repository.stopExpected();
    } on Object {
      if (_repository.isRunning) {
        final int? recoveredPid = _repository.activePid ?? pid;
        _publish(
          recoveredPid == null ? const BridgeProcessStopping(pid: null) : BridgeProcessRunning(pid: recoveredPid),
        );
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
    _activePid = null;
    final bool stableRun = _wasStableRun();
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
      ),
    );
  }

  Future<void> _finishExitCleanup({
    required Future<void> cleanup,
    required BridgeProcessExit? exit,
    required bool stableRun,
    required int generation,
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
        _restartAutomatically(
          generation: generation,
          context: "Bridge restart after supervised restart exit",
        );
        return;
      case BridgeSupervisedExitCode.authRequired:
        _crashCount = 0;
        _publish(const BridgeProcessLoginRequired());
        return;
      case BridgeSupervisedExitCode.bridgeContention:
        _crashCount = 0;
        _publish(const BridgeProcessContention());
        return;
      case null:
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
    if (state is! AuthAuthenticated ||
        _disposed ||
        _desiredState == BridgeProcessDesiredState.off ||
        this.state is! BridgeProcessLoginRequired) {
      return;
    }
    _crashCount = 0;
    _restartAutomatically(
      generation: _lifecycleGeneration,
      context: "Bridge start after successful authentication",
    );
  }

  void _onHelperConnectionChanged({required bool connected}) {
    if (connected && _activePid != null) {
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
      await _authSubscription.cancel();
      await _helperConnectionSubscription.cancel();
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

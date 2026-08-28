import "dart:async";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/control_channel_server.dart";
import "../foundation/platform/bridge_executable_path_resolver.dart";
import "../repositories/bridge_process_repository.dart";
import "../trackers/bridge_process_log_tracker.dart";

sealed class const BridgeProcessState();

final class const BridgeProcessStopped() extends BridgeProcessState;

final class const BridgeProcessLoginRequired() extends BridgeProcessState;

final class const BridgeProcessStarting() extends BridgeProcessState;

final class const BridgeProcessRunning({required final int pid}) extends BridgeProcessState;

final class const BridgeProcessStopping({required final int pid}) extends BridgeProcessState;

final class const BridgeProcessExitedDuringStartException({required final int pid}) implements Exception {
  @override
  String toString() => "BridgeProcessExitedDuringStartException: bridge process $pid exited during startup";
}

@visibleForTesting
typedef BridgeProcessServiceWarningReporter = void Function({
  required String message,
  required Object error,
  required StackTrace stackTrace,
});

/// Layer-3 lifecycle owner for the desktop-supervised bridge helper.
///
/// A start is transactional: it creates one fresh control server, spawns only
/// for an authenticated desktop session, attaches both child pipes, and sends
/// the per-spawn secret over stdin. Any failure attempts an expected child stop
/// and control-server teardown before rethrowing the original failure.
@lazySingleton
class BridgeProcessService.forTesting({
  required final BridgeProcessRepository _repository,
  required final BridgeProcessLogTracker _logTracker,
  required final ControlChannelServer _controlChannelServer,
  required final AuthSession _authSession,
  required final BridgeExecutablePathResolver _executablePathResolver,
  required final BridgeProcessServiceWarningReporter _reportWarning,
}) {
  late final StreamSubscription<BridgeProcessExit> _exitSubscription;
  final BehaviorSubject<BridgeProcessState> _states = BehaviorSubject<BridgeProcessState>.seeded(
    const BridgeProcessStopped(),
  );
  Future<void> _exitCleanup = Future<void>.value();
  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  int? _activePid;
  bool _disposed = false;

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
         reportWarning: _logWarning,
       );

  @visibleForTesting
  this {
    _exitSubscription = _repository.exits.listen(
      _onExit,
      onError: _onExitError,
    );
  }

  BridgeProcessState get state => _states.value;

  ValueStream<BridgeProcessState> get states => _states.stream;

  Future<void> start() async {
    _ensureNotDisposed();
    final Future<void>? existing = _startFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final Future<void> operation = _start();
    _startFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_startFuture, operation)) {
        _startFuture = null;
      }
    }
  }

  Future<void> _start() async {
    final Future<void>? stop = _stopFuture;
    if (stop != null) {
      await stop;
    }
    await _exitCleanup;

    if (_activePid != null || _repository.isRunning) {
      return;
    }
    if (_authSession.currentState is! AuthAuthenticated) {
      _setState(const BridgeProcessLoginRequired());
      return;
    }

    _setState(const BridgeProcessStarting());
    bool controlStartAttempted = false;
    bool childCreated = false;
    try {
      controlStartAttempted = true;
      await _controlChannelServer.start();
      final Uri controlUrl = _controlChannelServer.url;
      final String controlSecret = _controlChannelServer.secret;
      final BridgeProcessStreams streams = await _repository.spawn(
        executable: _executablePathResolver.resolve(),
        arguments: <String>["--control-url", controlUrl.toString()],
        workingDirectory: null,
        environment: null,
      );
      childCreated = true;
      _activePid = streams.pid;

      await _logTracker.attach(stdout: streams.stdout, stderr: streams.stderr);
      streams.stdin.writeln(controlSecret);
      await streams.stdin.flush();

      if (_activePid != streams.pid || !_repository.isRunning) {
        throw BridgeProcessExitedDuringStartException(pid: streams.pid);
      }
      _setState(BridgeProcessRunning(pid: streams.pid));
    } on Object catch (_) {
      await _rollbackFailedStart(
        childCreated: childCreated,
        controlStartAttempted: controlStartAttempted,
      );
      rethrow;
    }
  }

  Future<void> stop() async {
    _ensureNotDisposed();
    final Future<void>? existing = _stopFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final Future<void> operation = _stop();
    _stopFuture = operation;
    try {
      await operation;
    } finally {
      if (identical(_stopFuture, operation)) {
        _stopFuture = null;
      }
    }
  }

  Future<void> _stop() async {
    final Future<void>? start = _startFuture;
    if (start != null) {
      try {
        await start;
      } on Object {
        // The start caller receives the original failure, while its rollback
        // already owns child/server cleanup. Continue this explicit stop.
      }
    }

    final int? pid = _activePid ?? _repository.activePid;
    if (pid != null) {
      _setState(BridgeProcessStopping(pid: pid));
    }
    try {
      await _repository.stopExpected();
    } on Object {
      if (_repository.isRunning && pid != null) {
        _setState(BridgeProcessRunning(pid: pid));
      }
      rethrow;
    }

    _activePid = null;
    await _exitCleanup;
    await _controlChannelServer.stop();
    _setState(const BridgeProcessStopped());
  }

  Future<void> _rollbackFailedStart({
    required bool childCreated,
    required bool controlStartAttempted,
  }) async {
    if (childCreated) {
      try {
        await _repository.stopExpected();
      } on Object catch (error, stackTrace) {
        _reportWarning(
          message: "Failed to stop the bridge after supervised startup failed",
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    await _exitCleanup;
    if (controlStartAttempted) {
      try {
        await _controlChannelServer.stop();
      } on Object catch (error, stackTrace) {
        _reportWarning(
          message: "Failed to stop the control channel after supervised startup failed",
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (_repository.isRunning) {
      final int? pid = _repository.activePid ?? _activePid;
      if (pid != null) {
        _activePid = pid;
        _setState(BridgeProcessStopping(pid: pid));
        return;
      }
    }
    _activePid = null;
    _setState(const BridgeProcessStopped());
  }

  void _onExit(BridgeProcessExit exit) {
    if (_activePid != exit.pid) {
      return;
    }
    _activePid = null;
    _exitCleanup = _cleanUpExitedProcess();
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, Stream.listen error callbacks are positional
  void _onExitError(Object error, StackTrace stackTrace) {
    _reportWarning(
      message: "Failed to observe the supervised bridge exit",
      error: error,
      stackTrace: stackTrace,
    );
    _activePid = null;
    _exitCleanup = _cleanUpExitedProcess();
  }

  Future<void> _cleanUpExitedProcess() async {
    try {
      await _controlChannelServer.stop();
    } on Object catch (error, stackTrace) {
      _reportWarning(
        message: "Failed to stop the control channel after the bridge exited",
        error: error,
        stackTrace: stackTrace,
      );
    }
    _setState(const BridgeProcessStopped());
  }

  void _setState(BridgeProcessState state) {
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
      await _exitSubscription.cancel();
      await _controlChannelServer.stop();
      await _states.close();
    }
  }
}

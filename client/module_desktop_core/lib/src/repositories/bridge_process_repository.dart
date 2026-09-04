import "dart:async";
import "dart:convert";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/bridge_process_api.dart";
import "../foundation/control_channel_server.dart";

/// The raw child streams handed upward after a successful repository spawn.
/// Exit observation stays inside [BridgeProcessRepository].
class BridgeProcessStreams({
  required final int pid,
  required final IOSink stdin,
  required final Stream<List<int>> stdout,
  required final Stream<List<int>> stderr,
});

/// One child-process completion with the expected-stop marker captured at the
/// instant the process exited.
@immutable
class const BridgeProcessExit({
  required final int pid,
  required final int exitCode,
  required final bool expected,
}) {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeProcessExit && pid == other.pid && exitCode == other.exitCode && expected == other.expected;

  @override
  int get hashCode => Object.hash(pid, exitCode, expected);
}

final class const BridgeProcessAlreadyRunningException({required final int pid}) implements Exception {
  @override
  String toString() => "BridgeProcessAlreadyRunningException: bridge process $pid is still active";
}

/// The sole Layer-2 boundary over bridge child-process operations.
///
/// It owns the one active process, its expected-exit marker, exit events, raw
/// stdio hand-off, and the atomic expected stop. The expected stop marks first,
/// then asks the helper to shut down over the control channel. If that channel
/// is absent it uses catchable SIGTERM on POSIX; if no graceful request can be
/// delivered, or the full bridge teardown deadline expires, it force-kills the
/// entire process tree without clearing the marker.
@lazySingleton
class BridgeProcessRepository.forTesting({
  required final BridgeProcessApi _processApi,
  required final ControlChannelServer _controlChannelServer,
  required final Duration _gracefulShutdownTimeout,
  required final Duration _forcedExitTimeout,
}) {
  new({
    required BridgeProcessApi processApi,
    required ControlChannelServer controlChannelServer,
  }) : this.forTesting(
         processApi: processApi,
         controlChannelServer: controlChannelServer,
         gracefulShutdownTimeout: defaultGracefulShutdownTimeout,
         forcedExitTimeout: defaultForcedExitTimeout,
       );

  @visibleForTesting
  this;

  /// Strictly exceeds the bridge coordinator's maximum graceful path: current
  /// phase budgets (30s) + backstop slack (10s) + emergency disposal cap (6s).
  /// The desktop fallback therefore cannot pre-empt plugin/backend disposal.
  static const Duration defaultGracefulShutdownTimeout = Duration(seconds: 60);
  static const Duration defaultForcedExitTimeout = Duration(seconds: 5);

  final StreamController<BridgeProcessExit> _exits = StreamController<BridgeProcessExit>.broadcast(sync: true);
  _ActiveBridgeProcess? _active;

  Stream<BridgeProcessExit> get exits => _exits.stream;

  bool get isRunning => _active != null;

  int? get activePid => _active?.handle.pid;

  /// Resolves the child environment through the Layer-1 process boundary.
  Future<Map<String, String>> resolveEnvironment() => _processApi.resolveEnvironment();

  Future<BridgeProcessStreams> spawn({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
  }) async {
    final _ActiveBridgeProcess? existing = _active;
    if (existing != null) {
      throw BridgeProcessAlreadyRunningException(pid: existing.handle.pid);
    }

    final BridgeProcessApiHandle handle = await _processApi.spawn(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    final _ActiveBridgeProcess active = _ActiveBridgeProcess(handle: handle);
    _active = active;
    unawaited(_observeExit(active: active));
    return BridgeProcessStreams(
      pid: handle.pid,
      stdin: handle.stdin,
      stdout: handle.stdout,
      stderr: handle.stderr,
    );
  }

  /// Atomically marks the current child as expected and stops it.
  ///
  /// Repeated callers join the same stop operation. A force-kill fallback never
  /// clears [BridgeProcessExit.expected], so exit-policy consumers cannot
  /// mistake a helper that hung during an intentional stop for a crash.
  Future<void> stopExpected() {
    final _ActiveBridgeProcess? active = _active;
    if (active == null) {
      return Future<void>.value();
    }
    final Future<void>? existing = active.stopFuture;
    if (existing != null) {
      // A logout-owned wait can be upgraded when command delivery fails. The
      // active operation remains the single owner of teardown; this only
      // wakes it so it can send the ordinary shutdown fallback.
      if (active.stopMode == _BridgeStopMode.afterCommand) {
        requestExpectedShutdown();
      }
      return existing;
    }
    active.stopMode = _BridgeStopMode.ordinary;
    return active.stopFuture ??= _runStopExpected(active: active);
  }

  /// Marks the current child as expected and waits for a shutdown command that
  /// was already sent by another owner, without sending a competing shutdown.
  ///
  /// The unregister-and-exit logout command owns the helper's graceful request.
  /// This path keeps the token service alive until that command's unregister
  /// request has completed, while retaining the same bounded force-kill
  /// fallback if the helper does not exit. If delivery later fails, callers
  /// can invoke [requestExpectedShutdown] to upgrade this same wait.
  Future<void> stopExpectedAfterCommand() {
    final _ActiveBridgeProcess? active = _active;
    if (active == null) {
      return Future<void>.value();
    }
    final Future<void>? existing = active.stopFuture;
    if (existing != null) {
      return existing;
    }
    active.stopMode = _BridgeStopMode.afterCommand;
    active.shutdownFallback ??= Completer<void>();
    return active.stopFuture ??= _runStopExpectedAfterCommand(active: active);
  }

  /// Wakes an after-command stop so it can send the ordinary shutdown
  /// fallback. This is synchronous by design: the process repository retains
  /// ownership of the in-flight stop future and never starts a second teardown.
  void requestExpectedShutdown() {
    final _ActiveBridgeProcess? active = _active;
    final Completer<void>? fallback = active?.shutdownFallback;
    if (active?.stopMode != _BridgeStopMode.afterCommand || fallback == null || fallback.isCompleted) {
      return;
    }
    fallback.complete();
  }

  Future<void> _runStopExpected({required _ActiveBridgeProcess active}) async {
    try {
      await _stopExpected(active: active);
    } on Object {
      // Keep concurrent callers on one atomic stop attempt, but do not let one
      // failed platform command permanently poison future Off/Quit retries.
      if (identical(_active, active)) {
        active.stopFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _runStopExpectedAfterCommand({required _ActiveBridgeProcess active}) async {
    try {
      active.expected = true;
      final Completer<void> fallback = active.shutdownFallback ??= Completer<void>();
      final _AfterCommandStopTrigger trigger;
      try {
        trigger = await Future.any<_AfterCommandStopTrigger>(<Future<_AfterCommandStopTrigger>>[
          active.handle.exitCode.then((_) => _AfterCommandStopTrigger.exited),
          fallback.future.then((_) => _AfterCommandStopTrigger.shutdownRequested),
        ]).timeout(_gracefulShutdownTimeout);
      } on TimeoutException {
        await _forceKillAndWait(active: active);
        return;
      }
      if (trigger == _AfterCommandStopTrigger.shutdownRequested) {
        await _stopExpected(active: active);
      }
    } on Object {
      if (identical(_active, active)) {
        active.stopFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _stopExpected({required _ActiveBridgeProcess active}) async {
    active.expected = true;
    bool gracefulRequestDelivered = false;
    try {
      const ControlMessage message = ControlMessage.shutdown();
      _controlChannelServer.send(jsonEncode(message.toJson()));
      gracefulRequestDelivered = true;
    } on ControlHelperNotConnectedException {
      gracefulRequestDelivered = _tryGracefulSignal(active: active);
    } on Object catch (error, stackTrace) {
      logw("Failed to request bridge shutdown over the control channel", error, stackTrace);
      gracefulRequestDelivered = _tryGracefulSignal(active: active);
    }

    if (!gracefulRequestDelivered) {
      if (await _alreadyExited(active: active)) {
        return;
      }
      await _forceKillAndWait(active: active);
      return;
    }

    await _waitForExitOrForceKill(active: active);
  }

  Future<void> _waitForExitOrForceKill({required _ActiveBridgeProcess active}) async {
    try {
      await active.handle.exitCode.timeout(_gracefulShutdownTimeout);
    } on TimeoutException {
      await _forceKillAndWait(active: active);
    }
  }

  bool _tryGracefulSignal({required _ActiveBridgeProcess active}) {
    try {
      return _processApi.sendGracefulSignal(pid: active.handle.pid);
    } on Object catch (error, stackTrace) {
      logw("Failed to signal the bridge process for graceful shutdown", error, stackTrace);
      return false;
    }
  }

  Future<bool> _alreadyExited({required _ActiveBridgeProcess active}) async {
    try {
      await active.handle.exitCode.timeout(Duration.zero);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _forceKillAndWait({required _ActiveBridgeProcess active}) async {
    await _processApi.killProcessTree(pid: active.handle.pid).timeout(_forcedExitTimeout);
    await active.handle.exitCode.timeout(_forcedExitTimeout);
  }

  Future<void> _observeExit({required _ActiveBridgeProcess active}) async {
    try {
      final int exitCode = await active.handle.exitCode;
      if (identical(_active, active)) {
        _active = null;
      }
      if (!_exits.isClosed) {
        _exits.add(
          BridgeProcessExit(
            pid: active.handle.pid,
            exitCode: exitCode,
            expected: active.expected,
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      if (identical(_active, active)) {
        _active = null;
      }
      if (!_exits.isClosed) {
        _exits.addError(error, stackTrace);
      }
    } finally {
      try {
        await active.handle.stdin.close();
      } on Object catch (error, stackTrace) {
        logw("Failed to close bridge process stdin after exit", error, stackTrace);
      }
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await stopExpected();
    await _exits.close();
  }
}

enum _BridgeStopMode() { ordinary, afterCommand }

enum _AfterCommandStopTrigger() { exited, shutdownRequested }

class _ActiveBridgeProcess({required final BridgeProcessApiHandle handle}) {
  bool expected = false;
  Future<void>? stopFuture;
  _BridgeStopMode? stopMode;
  Completer<void>? shutdownFallback;
}

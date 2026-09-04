import "dart:async";

import "../trackers/bridge_process_log_tracker.dart";

/// Lifecycle state published by `BridgeProcessService`.
sealed class const BridgeProcessState();

/// No supervised helper is running or scheduled.
final class const BridgeProcessStopped() extends BridgeProcessState;

/// The bridge is desired On but an authenticated session is required first.
final class const BridgeProcessLoginRequired() extends BridgeProcessState;

/// The per-spawn control channel and child process are being created.
final class const BridgeProcessStarting() extends BridgeProcessState;

/// A supervised helper is currently running.
final class const BridgeProcessRunning({required final int pid}) extends BridgeProcessState;

/// An expected stop is in progress.
final class const BridgeProcessStopping({required final int pid}) extends BridgeProcessState;

/// Another standalone or supervised bridge currently owns this machine.
///
/// Render this as state even during hidden startup; presentation layers decide
/// when to surface a window and must never turn silent autostart into a modal.
final class const BridgeProcessContention() extends BridgeProcessState;

/// An unexpected exit is waiting for its bounded retry delay.
final class const BridgeProcessCrashRetryScheduled({
  required final int? exitCode,
  required final int crashCount,
  required final Duration delay,
}) extends BridgeProcessState;

/// The bounded crash budget is exhausted and automatic retries have stopped.
final class BridgeProcessCrashGiveUp({
  required final int? exitCode,
  required final int crashCount,
  required List<BridgeProcessLogEntry> recentLogs,
}) extends BridgeProcessState {
  final List<BridgeProcessLogEntry> recentLogs = List<BridgeProcessLogEntry>.unmodifiable(recentLogs);
}

/// The child exited after spawn but before startup could complete.
final class const BridgeProcessExitedDuringStartException({
  required final int pid,
  required final AsyncError? innerCause,
}) implements Exception {
  @override
  String toString() => "BridgeProcessExitedDuringStartException: bridge process $pid exited during startup";
}

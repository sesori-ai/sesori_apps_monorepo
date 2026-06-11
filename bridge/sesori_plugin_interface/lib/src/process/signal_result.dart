import "dart:io";

enum ShutdownSignal { graceful, force }

/// Outcome of delivering a shutdown signal to a process.
///
/// Carries the platform [ProcessSignal] that was actually sent — the
/// interface package is CLI-only, so depending on `dart:io` here is accepted.
class SignalResult {
  const SignalResult({
    required this.pid,
    required this.requestedSignal,
    required this.deliveredSignal,
    required this.wasRequested,
    required this.attemptedAt,
  });

  final int pid;
  final ShutdownSignal requestedSignal;
  final ProcessSignal deliveredSignal;
  final bool wasRequested;
  final DateTime attemptedAt;
}

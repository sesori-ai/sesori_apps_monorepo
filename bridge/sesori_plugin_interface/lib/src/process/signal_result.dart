import "dart:io";

enum ShutdownSignal() { graceful, force }

/// Outcome of delivering a shutdown signal to a process.
///
/// Carries the platform [ProcessSignal] that was actually sent — the
/// interface package is CLI-only, so depending on `dart:io` here is accepted.
class const SignalResult({
    required final int pid,
    required final ShutdownSignal requestedSignal,
    required final ProcessSignal deliveredSignal,
    required final bool wasRequested,
    required final DateTime attemptedAt,
  });

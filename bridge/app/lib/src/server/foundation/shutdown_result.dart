import 'dart:io';

enum ShutdownSignal { graceful, force }

class ShutdownResult {
  const ShutdownResult({
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

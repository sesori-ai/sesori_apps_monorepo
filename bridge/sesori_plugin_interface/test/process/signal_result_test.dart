import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('SignalResult', () {
    test('carries the delivery facts it was constructed with', () {
      final attemptedAt = DateTime.utc(2026, 6, 10, 12);
      final result = SignalResult(
        pid: 42,
        requestedSignal: ShutdownSignal.graceful,
        deliveredSignal: ProcessSignal.sigterm,
        wasRequested: true,
        attemptedAt: attemptedAt,
      );

      expect(result.pid, 42);
      expect(result.requestedSignal, ShutdownSignal.graceful);
      expect(result.deliveredSignal, ProcessSignal.sigterm);
      expect(result.wasRequested, isTrue);
      expect(result.attemptedAt, attemptedAt);
    });

    test('ShutdownResult remains usable as an alias during the migration', () {
      final ShutdownResult result = SignalResult(
        pid: 7,
        requestedSignal: ShutdownSignal.force,
        deliveredSignal: ProcessSignal.sigkill,
        wasRequested: false,
        attemptedAt: DateTime.utc(2026, 6, 10),
      );
      expect(result, isA<SignalResult>());
    });
  });
}

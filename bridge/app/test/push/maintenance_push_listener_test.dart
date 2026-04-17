import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/maintenance_push_listener.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:test/test.dart";

void main() {
  group("MaintenancePushListener", () {
    test("construction is passive until start", () {
      fakeAsync((async) {
        final harness = _newHarness(
          maintenanceInterval: const Duration(minutes: 2),
        );
        addTearDown(harness.dispose);

        expect(harness.listener.lastMaintenanceTelemetry, isNull);

        async.elapse(const Duration(minutes: 3));
        async.flushMicrotasks();

        expect(harness.listener.lastMaintenanceTelemetry, isNull);

        harness.listener.start();

        async.elapse(const Duration(minutes: 1, seconds: 59));
        async.flushMicrotasks();

        expect(harness.listener.lastMaintenanceTelemetry, isNull);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(harness.listener.lastMaintenanceTelemetry, isNotNull);
      });
    });

    test("start is idempotent", () {
      fakeAsync((async) {
        final harness = _newHarness(
          maintenanceInterval: const Duration(minutes: 1),
        );
        addTearDown(harness.dispose);

        harness.listener.start();
        harness.listener.start();

        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        final firstTelemetry = harness.listener.lastMaintenanceTelemetry;

        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();

        expect(firstTelemetry, isNotNull);
        expect(harness.listener.lastMaintenanceTelemetry, isNotNull);
      });
    });

    test("runNow captures exactly one maintenance snapshot", () {
      final harness = _newHarness();
      addTearDown(harness.dispose);

      harness.listener.runNow();

      expect(harness.listener.lastMaintenanceTelemetry, isNotNull);
    });

    test("dispose cancels the periodic timer", () {
      fakeAsync((async) {
        final harness = _newHarness(
          maintenanceInterval: const Duration(minutes: 1),
        );
        addTearDown(harness.dispose);

        harness.listener.start();

        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        final firstTelemetry = harness.listener.lastMaintenanceTelemetry;
        expect(firstTelemetry, isNotNull);

        harness.listener.dispose();

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(identical(harness.listener.lastMaintenanceTelemetry, firstTelemetry), isTrue);
      });
    });
  });
}

class _Harness {
  final MaintenancePushListener listener;

  _Harness({required this.listener});

  void dispose() {
    listener.dispose();
  }
}

_Harness _newHarness({Duration maintenanceInterval = const Duration(minutes: 10)}) {
  final tracker = PushSessionStateTracker(now: DateTime.now);
  final notifier = CompletionNotifier(
    tracker: tracker,
    debounceDuration: const Duration(milliseconds: 500),
  );
  final rateLimiter = PushRateLimiter(now: DateTime.now);
  final listener = MaintenancePushListener(
    tracker: tracker,
    completionNotifier: notifier,
    rateLimiter: rateLimiter,
    telemetryBuilder: PushMaintenanceTelemetryBuilder(
      completionNotifier: notifier,
      rateLimiter: rateLimiter,
      rssBytesReader: () => null,
    ),
    maintenanceInterval: maintenanceInterval,
  );

  return _Harness(listener: listener);
}

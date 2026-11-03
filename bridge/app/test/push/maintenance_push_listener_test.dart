import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/maintenance_push_listener.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:test/test.dart";

void main() {
  group("MaintenancePushListener", () {
    test("construction is passive until start", () {
      fakeAsync((async) {
        final harness = _newHarness(maintenanceInterval: const Duration(minutes: 2));
        addTearDown(harness.listener.dispose);

        async.elapse(const Duration(minutes: 3));
        expect(harness.rateLimiter.pruneCount, 0);

        harness.listener.start();

        async.elapse(const Duration(minutes: 1, seconds: 59));
        expect(harness.rateLimiter.pruneCount, 0);

        async.elapse(const Duration(seconds: 1));
        expect(harness.rateLimiter.pruneCount, 1);
      });
    });

    test("start is idempotent", () {
      fakeAsync((async) {
        final harness = _newHarness(maintenanceInterval: const Duration(minutes: 1));
        addTearDown(harness.listener.dispose);

        harness.listener.start();
        harness.listener.start();

        async.elapse(const Duration(minutes: 2));

        expect(harness.rateLimiter.pruneCount, 2);
      });
    });

    test("runNow runs one maintenance pass", () {
      final harness = _newHarness();
      addTearDown(harness.listener.dispose);

      harness.listener.runNow();

      expect(harness.rateLimiter.pruneCount, 1);
    });

    test("dispose cancels the periodic timer", () {
      fakeAsync((async) {
        final harness = _newHarness(maintenanceInterval: const Duration(minutes: 1));

        harness.listener.start();
        async.elapse(const Duration(minutes: 1));
        expect(harness.rateLimiter.pruneCount, 1);

        harness.listener.dispose();
        async.elapse(const Duration(minutes: 5));

        expect(harness.rateLimiter.pruneCount, 1);
      });
    });
  });
}

class _CountingRateLimiter({required super.now}) extends PushRateLimiter {
  int pruneCount = 0;

  @override
  void pruneStaleEntries() {
    pruneCount += 1;
    super.pruneStaleEntries();
  }
}

({MaintenancePushListener listener, _CountingRateLimiter rateLimiter}) _newHarness({
  Duration maintenanceInterval = const Duration(minutes: 10),
}) {
  final tracker = PushSessionStateTracker(now: DateTime.now);
  final rateLimiter = _CountingRateLimiter(now: DateTime.now);
  final listener = MaintenancePushListener(
    tracker: tracker,
    completionNotifier: CompletionNotifier(tracker: tracker),
    rateLimiter: rateLimiter,
    maintenanceInterval: maintenanceInterval,
  );
  return (listener: listener, rateLimiter: rateLimiter);
}

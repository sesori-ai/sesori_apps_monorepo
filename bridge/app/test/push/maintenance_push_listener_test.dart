import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/push/maintenance_push_listener.dart";
import "package:sesori_bridge/src/push/push_dispatcher.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("MaintenancePushListener", () {
    test("construction is passive until start", () {
      fakeAsync((async) {
        final harness = _newHarness(
          maintenanceInterval: const Duration(minutes: 2),
        );
        addTearDown(harness.dispose);

        expect(harness.dispatcher.runMaintenancePassCalls, equals(0));

        async.elapse(const Duration(minutes: 3));
        async.flushMicrotasks();

        expect(harness.dispatcher.runMaintenancePassCalls, equals(0));

        harness.listener.start();

        async.elapse(const Duration(minutes: 1, seconds: 59));
        async.flushMicrotasks();

        expect(harness.dispatcher.runMaintenancePassCalls, equals(0));

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(harness.dispatcher.runMaintenancePassCalls, equals(1));
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

        expect(harness.dispatcher.runMaintenancePassCalls, equals(1));

        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();

        expect(harness.dispatcher.runMaintenancePassCalls, equals(2));
      });
    });

    test("runNow delegates exactly one maintenance pass", () {
      final harness = _newHarness();
      addTearDown(harness.dispose);

      harness.listener.runNow();

      expect(harness.dispatcher.runMaintenancePassCalls, equals(1));
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
        expect(harness.dispatcher.runMaintenancePassCalls, equals(1));

        harness.listener.dispose();

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(harness.dispatcher.runMaintenancePassCalls, equals(1));
      });
    });
  });
}

class _Harness {
  final MaintenancePushListener listener;
  final FakePushDispatcher dispatcher;

  _Harness({
    required this.listener,
    required this.dispatcher,
  });

  void dispose() {
    listener.dispose();
  }
}

_Harness _newHarness({
  FakePushDispatcher? dispatcher,
  Duration maintenanceInterval = const Duration(minutes: 10),
}) {
  final resolvedDispatcher = dispatcher ?? FakePushDispatcher();
  final listener = MaintenancePushListener(
    dispatcher: resolvedDispatcher,
    maintenanceInterval: maintenanceInterval,
  );

  return _Harness(
    listener: listener,
    dispatcher: resolvedDispatcher,
  );
}

class FakePushDispatcher implements PushDispatcher {
  int runMaintenancePassCalls = 0;

  @override
  PushMaintenanceTelemetrySnapshot? get lastMaintenanceTelemetry => null;

  @override
  void dispatchCompletionForRoot({required String rootSessionId}) {}

  @override
  Future<void> dispose() async {}

  @override
  void handleSseEvent(SesoriSseEvent event) {}

  @override
  void markSessionAborted(String sessionId) {}

  @override
  void reset() {}

  @override
  void runMaintenancePass() {
    runMaintenancePassCalls += 1;
  }
}

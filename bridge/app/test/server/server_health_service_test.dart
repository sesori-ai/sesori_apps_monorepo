import "dart:async";
import "dart:collection";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/server/server_health_config.dart";
import "package:sesori_bridge/src/server/server_health_event.dart";
import "package:sesori_bridge/src/server/server_health_service.dart";
import "package:sesori_bridge/src/server/server_lifecycle_service.dart";
import "package:test/test.dart";

void main() {
  group("ServerHealthService", () {
    test("onServerUnreachable from running emits unreachable", () async {
      final lifecycle = _FakeServerLifecycleService();
      final service = ServerHealthService(lifecycleService: lifecycle);
      final events = <ServerHealthEvent>[];
      final subscription = service.events.listen(events.add);

      service.onServerUnreachable("connection lost");
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single, isA<ServerHealthEventUnreachable>());
      expect((events.single as ServerHealthEventUnreachable).message, equals("connection lost"));

      await subscription.cancel();
      await service.dispose();
      await lifecycle.dispose();
    });

    test("onServerReachable from unreachable emits running", () async {
      final lifecycle = _FakeServerLifecycleService();
      final service = ServerHealthService(lifecycleService: lifecycle);
      final events = <ServerHealthEvent>[];
      final subscription = service.events.listen(events.add);

      service.onServerUnreachable("temporary outage");
      service.onServerReachable();
      await pumpEventQueue();

      expect(events, hasLength(2));
      expect(events[0], isA<ServerHealthEventUnreachable>());
      expect(events[1], isA<ServerHealthEventRunning>());

      await subscription.cancel();
      await service.dispose();
      await lifecycle.dispose();
    });

    test("process exit from running emits restarting attempt 1 and schedules restart", () {
      fakeAsync((async) {
        final lifecycle = _FakeServerLifecycleService();
        final service = ServerHealthService(lifecycleService: lifecycle);
        final events = <ServerHealthEvent>[];
        final subscription = service.events.listen(events.add);

        service.onProcessExited(137);
        async.flushMicrotasks();

        expect(events, hasLength(1));
        expect(events.single, isA<ServerHealthEventRestarting>());
        expect((events.single as ServerHealthEventRestarting).attempt, equals(1));
        expect(lifecycle.restartCallCount, equals(0));

        async.elapse(Duration.zero);
        async.flushMicrotasks();

        expect(lifecycle.restartCallCount, equals(1));

        subscription.cancel();
        service.dispose();
        lifecycle.dispose();
      });
    });

    test("restart success from restarting emits running", () {
      fakeAsync((async) {
        final lifecycle = _FakeServerLifecycleService();
        final service = ServerHealthService(lifecycleService: lifecycle);
        final events = <ServerHealthEvent>[];
        final subscription = service.events.listen(events.add);

        service.onProcessExited(1);
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        expect(events, hasLength(2));
        expect(events[0], isA<ServerHealthEventRestarting>());
        expect((events[0] as ServerHealthEventRestarting).attempt, equals(1));
        expect(events[1], isA<ServerHealthEventRunning>());

        subscription.cancel();
        service.dispose();
        lifecycle.dispose();
      });
    });

    test("restart failure below attempt 4 emits next restarting attempt", () {
      fakeAsync((async) {
        final lifecycle = _FakeServerLifecycleService(restartOutcomes: [Exception("boom")]);
        final service = ServerHealthService(lifecycleService: lifecycle);
        final events = <ServerHealthEvent>[];
        final subscription = service.events.listen(events.add);

        service.onProcessExited(1);
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        expect(events, hasLength(2));
        expect(events[0], isA<ServerHealthEventRestarting>());
        expect((events[0] as ServerHealthEventRestarting).attempt, equals(1));
        expect(events[1], isA<ServerHealthEventRestarting>());
        expect((events[1] as ServerHealthEventRestarting).attempt, equals(2));

        subscription.cancel();
        service.dispose();
        lifecycle.dispose();
      });
    });

    test("restart failure on 4th attempt emits failed", () {
      fakeAsync((async) {
        final lifecycle = _FakeServerLifecycleService(
          restartOutcomes: [
            Exception("boom 1"),
            Exception("boom 2"),
            Exception("boom 3"),
            Exception("boom 4"),
          ],
        );
        final service = ServerHealthService(lifecycleService: lifecycle);
        final events = <ServerHealthEvent>[];
        final subscription = service.events.listen(events.add);

        service.onProcessExited(1);
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 120));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 240));
        async.flushMicrotasks();

        expect(lifecycle.restartCallCount, equals(4));
        expect(
          events.whereType<ServerHealthEventRestarting>().map((event) => event.attempt).toList(),
          equals([1, 2, 3, 4]),
        );
        expect(events.last, isA<ServerHealthEventFailed>());
        expect(
          (events.last as ServerHealthEventFailed).reason,
          equals("Server restart failed after 4 attempts"),
        );

        subscription.cancel();
        service.dispose();
        lifecycle.dispose();
      });
    });

    test("invalid transitions are ignored", () async {
      final lifecycle = _FakeServerLifecycleService();
      final service = ServerHealthService(lifecycleService: lifecycle);
      final events = <ServerHealthEvent>[];
      final subscription = service.events.listen(events.add);

      service.onServerReachable();
      await pumpEventQueue();

      expect(events, isEmpty);

      await subscription.cancel();
      await service.dispose();
      await lifecycle.dispose();
    });

    test("dispose cancels pending restart timers", () {
      fakeAsync((async) {
        final lifecycle = _FakeServerLifecycleService(restartOutcomes: [Exception("boom")]);
        final service = ServerHealthService(lifecycleService: lifecycle);

        service.onProcessExited(1);
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        expect(lifecycle.restartCallCount, equals(1));

        service.dispose();

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        expect(lifecycle.restartCallCount, equals(1));

        lifecycle.dispose();
      });
    });

    test("dispose closes event stream", () async {
      final lifecycle = _FakeServerLifecycleService();
      final service = ServerHealthService(lifecycleService: lifecycle);
      final done = expectLater(service.events, emitsDone);

      await service.dispose();
      await done;
      await lifecycle.dispose();
    });
  });
}

class _FakeServerLifecycleService extends ServerLifecycleService {
  final Queue<Object> _restartOutcomes;
  int restartCallCount = 0;

  _FakeServerLifecycleService({
    bool isManaged = true,
    List<Object> restartOutcomes = const [],
  }) : _restartOutcomes = Queue<Object>.from(restartOutcomes),
       super(
         config: ServerHealthConfig(
           serverURL: "http://127.0.0.1:4096",
           password: "password",
           binaryPath: "opencode",
           isManaged: isManaged,
         ),
         initialProcess: null,
       );

  @override
  Future<void> restart() async {
    restartCallCount++;
    if (_restartOutcomes.isEmpty) {
      return;
    }

    throw _restartOutcomes.removeFirst();
  }

  Future<void> dispose() async {
    return;
  }
}

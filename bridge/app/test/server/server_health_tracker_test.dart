import "dart:async";

import "package:sesori_bridge/src/server/server_health_event.dart";
import "package:sesori_bridge/src/server/server_health_tracker.dart";
import "package:sesori_shared/sesori_shared.dart" show ServerStateKind;
import "package:test/test.dart";

void main() {
  group("ServerHealthTracker", () {
    late StreamController<ServerHealthEvent> controller;
    late ServerHealthTracker tracker;

    setUp(() {
      controller = StreamController<ServerHealthEvent>.broadcast();
      tracker = ServerHealthTracker(events: controller.stream);
    });

    tearDown(() async {
      await tracker.dispose();
      await controller.close();
    });

    test("currentState starts as running", () {
      expect(tracker.currentState, equals(ServerStateKind.running));
    });

    test("unreachable event updates currentState and emits stateChanges", () async {
      final states = <ServerStateKind>[];
      final subscription = tracker.stateChanges.listen(states.add);

      controller.add(const ServerHealthEventUnreachable(message: "offline"));
      await pumpEventQueue();

      expect(tracker.currentState, equals(ServerStateKind.unreachable));
      expect(states, equals([ServerStateKind.unreachable]));

      await subscription.cancel();
    });

    test("restarting event updates currentState", () async {
      controller.add(const ServerHealthEventRestarting(attempt: 2));
      await pumpEventQueue();

      expect(tracker.currentState, equals(ServerStateKind.restarting));
    });

    test("failed event updates currentState", () async {
      controller.add(const ServerHealthEventFailed(reason: "restart exhausted"));
      await pumpEventQueue();

      expect(tracker.currentState, equals(ServerStateKind.failed));
    });

    test("running event updates currentState", () async {
      controller.add(const ServerHealthEventUnreachable(message: "offline"));
      controller.add(const ServerHealthEventRunning());
      await pumpEventQueue();

      expect(tracker.currentState, equals(ServerStateKind.running));
    });

    test("duplicate events do not emit duplicate stateChanges", () async {
      final states = <ServerStateKind>[];
      final subscription = tracker.stateChanges.listen(states.add);

      controller.add(const ServerHealthEventUnreachable(message: "offline"));
      controller.add(const ServerHealthEventUnreachable(message: "still offline"));
      await pumpEventQueue();

      expect(states, equals([ServerStateKind.unreachable]));

      await subscription.cancel();
    });

    test("dispose closes the stream", () async {
      final done = Completer<void>();
      tracker.stateChanges.listen(null, onDone: done.complete);

      await tracker.dispose();
      await done.future;
    });
  });
}

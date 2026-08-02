import "dart:async";
import "dart:collection";

import "package:sesori_bridge/src/bridge/routing/bridge_restart_dispatcher.dart";
import "package:sesori_bridge/src/bridge/routing/routed_request.dart";
import "package:sesori_bridge/src/server/services/bridge_restart_service.dart";
import "package:test/test.dart";

void main() {
  group("BridgeRestartDispatcher", () {
    test("shares one successful handoff and emits one synchronous shutdown request", () async {
      final gate = Completer<bool>();
      final service = _FakeRestartService(handoffs: Queue.of([() => gate.future]));
      final dispatcher = BridgeRestartDispatcher(restartService: service);
      addTearDown(dispatcher.dispose);
      final shutdownRequests = <BridgeShutdownRequest>[];
      dispatcher.shutdownRequests.listen(shutdownRequests.add);

      final first = dispatcher.dispatch(restart: const RestartAccepted(requestId: "one"));
      final duplicate = dispatcher.dispatch(restart: const RestartAccepted(requestId: "two"));

      expect(service.handoffCalls, 1);
      expect(shutdownRequests, isEmpty);
      gate.complete(true);
      await Future.wait([first, duplicate]);
      expect(shutdownRequests, [BridgeShutdownRequest.restart]);

      await dispatcher.dispatch(restart: const RestartAccepted(requestId: "three"));
      expect(service.handoffCalls, 1);
      expect(shutdownRequests, [BridgeShutdownRequest.restart]);
    });

    test("failed handoff emits nothing and permits a later retry", () async {
      final service = _FakeRestartService(
        handoffs: Queue.of([
          () async => false,
          () async => true,
        ]),
      );
      final dispatcher = BridgeRestartDispatcher(restartService: service);
      addTearDown(dispatcher.dispose);
      final shutdownRequests = <BridgeShutdownRequest>[];
      dispatcher.shutdownRequests.listen(shutdownRequests.add);

      await dispatcher.dispatch(restart: const RestartAccepted(requestId: "first"));
      expect(shutdownRequests, isEmpty);

      await dispatcher.dispatch(restart: const RestartAccepted(requestId: "retry"));
      expect(service.handoffCalls, 2);
      expect(shutdownRequests, [BridgeShutdownRequest.restart]);
    });

    test("handoff errors remain observable and do not poison retries", () async {
      final service = _FakeRestartService(
        handoffs: Queue.of([
          () => Future<bool>.error(StateError("handoff failed")),
          () async => true,
        ]),
      );
      final dispatcher = BridgeRestartDispatcher(restartService: service);
      addTearDown(dispatcher.dispose);

      await expectLater(
        dispatcher.dispatch(restart: const RestartAccepted(requestId: "first")),
        throwsA(isA<StateError>()),
      );
      await dispatcher.dispatch(restart: const RestartAccepted(requestId: "retry"));
      expect(service.handoffCalls, 2);
    });

    test("dispose closes output and rejects later dispatch", () async {
      final service = _FakeRestartService(handoffs: Queue<Future<bool> Function()>());
      final dispatcher = BridgeRestartDispatcher(restartService: service);
      final done = dispatcher.shutdownRequests.drain<void>();

      await dispatcher.dispose();
      await done;

      await expectLater(
        dispatcher.dispatch(restart: const RestartAccepted(requestId: "late")),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeRestartService implements BridgeRestartService {
  _FakeRestartService({required this.handoffs});

  final Queue<Future<bool> Function()> handoffs;
  int handoffCalls = 0;

  @override
  bool get supervisedRestartRequested => false;

  @override
  Future<bool> canRestart() async => true;

  @override
  Future<bool> canSpawnSuccessor() async => true;

  @override
  Future<bool> performRestartHandoff() {
    handoffCalls++;
    return handoffs.removeFirst()();
  }

  @override
  Future<bool> spawnSuccessor() async => true;
}

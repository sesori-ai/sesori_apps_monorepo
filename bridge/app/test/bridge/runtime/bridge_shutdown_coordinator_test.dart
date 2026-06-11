import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_shutdown_coordinator.dart";
import "package:test/test.dart";

void main() {
  group("BridgeShutdownCoordinator", () {
    test("runs ordered steps in order, before the parallel phase", () async {
      final coordinator = BridgeShutdownCoordinator(exitProcess: (_) {});
      final operations = <String>[];

      coordinator.add(disposable: () => operations.add("parallel.a"));
      coordinator.addOrdered(
        action: () async => operations.add("ordered.1"),
        budget: const Duration(seconds: 5),
      );
      coordinator.addOrdered(
        action: () async => operations.add("ordered.2"),
        budget: const Duration(seconds: 5),
      );
      coordinator.add(disposable: () => operations.add("parallel.b"));

      await coordinator.shutdown();

      expect(operations, ["ordered.1", "ordered.2", "parallel.a", "parallel.b"]);
    });

    test("a failing ordered step does not block later steps or the parallel phase, then surfaces", () async {
      final coordinator = BridgeShutdownCoordinator(exitProcess: (_) {});
      final operations = <String>[];

      coordinator.addOrdered(
        action: () async => throw StateError("plugin shutdown failed"),
        budget: const Duration(seconds: 5),
      );
      coordinator.addOrdered(
        action: () async => operations.add("ordered.2"),
        budget: const Duration(seconds: 5),
      );
      coordinator.add(disposable: () => operations.add("parallel"));

      await expectLater(
        coordinator.shutdown(),
        throwsA(isA<StateError>()),
        reason: "a failed plugin stop must stay loud (non-zero exit), as it was as a parallel disposable",
      );
      expect(operations, ["ordered.2", "parallel"]);
    });

    test("a synchronously throwing disposable does not prevent the others from running", () async {
      final coordinator = BridgeShutdownCoordinator(exitProcess: (_) {});
      final operations = <String>[];

      coordinator.add(disposable: () => throw StateError("sync disposable failure"));
      coordinator.add(disposable: () => operations.add("parallel.b"));

      await expectLater(coordinator.shutdown(), throwsA(isA<StateError>()));
      expect(operations, ["parallel.b"]);
    });

    test("repeated shutdown calls share one run", () async {
      final coordinator = BridgeShutdownCoordinator(exitProcess: (_) {});
      var disposals = 0;
      coordinator.add(disposable: () => disposals++);

      final first = coordinator.shutdown();
      final second = coordinator.shutdown();
      await first;
      await second;

      expect(identical(first, second), isTrue);
      expect(disposals, 1);
    });

    test("backstop fires at ordered budget plus slack with the latch-derived exit code", () {
      fakeAsync((async) {
        final exitCalls = <int>[];
        final coordinator = BridgeShutdownCoordinator(
          backstopExitCode: () => 1,
          exitProcess: exitCalls.add,
        );
        coordinator.addOrdered(
          action: () => Completer<void>().future,
          budget: const Duration(seconds: 10),
        );

        unawaited(coordinator.shutdown());
        async.elapse(const Duration(seconds: 19));
        expect(exitCalls, isEmpty, reason: "backstop is sized budget (10s) + slack (10s)");

        async.elapse(const Duration(seconds: 2));
        expect(exitCalls, [1]);
      });
    });

    test("backstop covers a hung parallel phase even with no ordered steps", () {
      fakeAsync((async) {
        final exitCalls = <int>[];
        final coordinator = BridgeShutdownCoordinator(exitProcess: exitCalls.add);
        coordinator.add(disposable: () => Completer<void>().future);

        unawaited(coordinator.shutdown());
        async.elapse(const Duration(seconds: 11));

        expect(exitCalls, [0]);
      });
    });

    test("backstop never fires when shutdown completes in time", () {
      fakeAsync((async) {
        final exitCalls = <int>[];
        final coordinator = BridgeShutdownCoordinator(exitProcess: exitCalls.add);
        coordinator.addOrdered(action: () async {}, budget: const Duration(seconds: 10));
        coordinator.add(disposable: () {});

        unawaited(coordinator.shutdown());
        async.elapse(const Duration(minutes: 5));

        expect(exitCalls, isEmpty);
      });
    });
  });
}

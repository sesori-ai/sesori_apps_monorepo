import "dart:async" show Completer;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show ParallelLock;
import "package:test/test.dart";

void main() {
  test("rejects a non-positive parallel operation limit", () {
    expect(
      () => ParallelLock(maxParallelOperations: 0),
      throwsArgumentError,
    );
  });

  test("runs callbacks up to the limit and admits waiters in FIFO order", () async {
    final lock = ParallelLock(maxParallelOperations: 2);
    final releases = [for (var index = 0; index < 4; index++) Completer<void>()];
    final started = <int>[];

    final operations = [
      for (var index = 0; index < releases.length; index++)
        lock.use(
          operation: () async {
            started.add(index);
            await releases[index].future;
            return index;
          },
        ),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1]);

    releases[1].complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1, 2]);

    releases[0].complete();
    await Future<void>.delayed(Duration.zero);
    expect(started, [0, 1, 2, 3]);

    releases[2].complete();
    releases[3].complete();
    expect(await Future.wait(operations), [0, 1, 2, 3]);
  });

  test("releases a permit when the callback throws", () async {
    final lock = ParallelLock(maxParallelOperations: 1);

    await expectLater(
      lock.use<void>(operation: () => throw StateError("failed")),
      throwsA(isA<StateError>()),
    );

    expect(await lock.use(operation: () => 42), 42);
  });
}

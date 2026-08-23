import "dart:async" show Completer, unawaited;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show KeyedParallelLock, ParallelLock;
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

  test("idle captures only operations submitted before access", () async {
    final lock = ParallelLock(maxParallelOperations: 1);
    final first = Completer<void>();
    final second = Completer<void>();
    unawaited(lock.use<void>(operation: () => first.future));
    final idle = lock.idle;
    unawaited(lock.use<void>(operation: () => second.future));

    first.complete();
    await idle;
    expect(second.isCompleted, isFalse);
    second.complete();
    await lock.idle;
  });

  test("keyed lock serializes each key and keeps different keys independent", () async {
    final lock = KeyedParallelLock<String>();
    final first = Completer<void>();
    final started = <String>[];
    final operations = [
      lock.use<void>(
        key: "a",
        operation: () async {
          started.add("a1");
          await first.future;
        },
      ),
      lock.use<void>(key: "a", operation: () async => started.add("a2")),
      lock.use<void>(key: "b", operation: () async => started.add("b1")),
    ];

    await Future<void>.delayed(Duration.zero);
    expect(started, ["a1", "b1"]);
    first.complete();
    await Future.wait(operations);
    expect(started, ["a1", "b1", "a2"]);
  });

  test("keyed lock recovers after errors and idle has snapshot semantics", () async {
    final lock = KeyedParallelLock<String>();
    final first = Completer<void>();
    final later = Completer<void>();
    final failed = lock.use<void>(
      key: "a",
      operation: () async {
        await first.future;
        throw StateError("failed");
      },
    );
    final idle = lock.idle;
    final subsequent = lock.use<int>(
      key: "a",
      operation: () async {
        await later.future;
        return 42;
      },
    );

    first.complete();
    await expectLater(failed, throwsStateError);
    await idle;
    later.complete();
    expect(await subsequent, 42);
    await lock.idleFor(key: "a");
  });
}

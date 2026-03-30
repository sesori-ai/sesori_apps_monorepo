import "dart:async";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

/// Yields to the event loop enough times for the drain loop to process
/// all pending events whose listener completes synchronously.
Future<void> pumpEventQueue([int times = 20]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group("EventQueue", () {
    // -----------------------------------------------------------------------
    // Basic dequeue
    // -----------------------------------------------------------------------
    group("basic dequeue", () {
      test("processes a single enqueued event", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async => processed.add(e));

        queue.enqueue("a");
        await pumpEventQueue();

        expect(processed, ["a"]);
        expect(queue.length, 0);
        sub.cancel();
        queue.dispose();
      });

      test("processes multiple events in FIFO order", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async => processed.add(e));

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c");
        await pumpEventQueue();

        expect(processed, ["a", "b", "c"]);
        expect(queue.length, 0);
        sub.cancel();
        queue.dispose();
      });

      test("events enqueued during listener are appended to the queue", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        queue.listen((e) async {
          processed.add(e);
          if (e == "a") {
            queue.enqueue("d");
          }
        });

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c");
        await pumpEventQueue();

        expect(processed, ["a", "d", "b", "c"]);
        queue.dispose();
      });

      test("drain auto-starts on first enqueue when listener attached", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        queue.listen((e) async => processed.add(e));

        queue.enqueue("x");
        await pumpEventQueue();

        expect(processed, ["x"]);
        queue.dispose();
      });

      test("sequential processing — second event waits for first to finish", () async {
        final order = <String>[];
        final gate = Completer<void>();

        final queue = EventQueue<String>();
        queue.listen((e) async {
          if (e == "slow") {
            order.add("slow-start");
            await gate.future;
            order.add("slow-end");
          } else {
            order.add(e);
          }
        });

        queue.enqueue("slow");
        queue.enqueue("fast");
        await pumpEventQueue();

        // "fast" has not been processed yet — drain is awaiting "slow"
        expect(order, ["slow-start"]);

        gate.complete();
        await pumpEventQueue();

        expect(order, ["slow-start", "slow-end", "fast"]);
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Buffering (no listener)
    // -----------------------------------------------------------------------
    group("buffering", () {
      test("events buffer when no listener is attached", () async {
        final queue = EventQueue<String>();

        queue.enqueue("a");
        queue.enqueue("b");
        await pumpEventQueue();

        expect(queue.hasListener, isFalse);
        expect(queue.length, 2);
        queue.dispose();
      });

      test("listen() flushes buffered events", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();

        queue.enqueue("a");
        queue.enqueue("b");
        expect(queue.length, 2);

        queue.listen((e) async => processed.add(e));
        await pumpEventQueue();

        expect(processed, ["a", "b"]);
        expect(queue.length, 0);
        queue.dispose();
      });

      test("cancel then re-listen flushes new buffer", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();

        final sub1 = queue.listen((e) async => processed.add("v1:$e"));
        queue.enqueue("a");
        await pumpEventQueue();
        expect(processed, ["v1:a"]);

        sub1.cancel();
        queue.enqueue("b"); // buffered, no listener
        queue.enqueue("c");
        expect(queue.length, 2);

        queue.listen((e) async => processed.add("v2:$e"));
        await pumpEventQueue();

        expect(processed, ["v1:a", "v2:b", "v2:c"]);
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Pause / Resume
    // -----------------------------------------------------------------------
    group("pause / resume", () {
      test("pause prevents dequeuing", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async => processed.add(e));

        sub.pause();
        queue.enqueue("a");
        queue.enqueue("b");
        await pumpEventQueue();

        expect(processed, isEmpty);
        expect(queue.length, 2);
        expect(queue.isPaused, isTrue);
        sub.cancel();
        queue.dispose();
      });

      test("resume processes the backlog", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async => processed.add(e));

        sub.pause();
        queue.enqueue("a");
        queue.enqueue("b");
        await pumpEventQueue();
        expect(processed, isEmpty);

        sub.resume();
        await pumpEventQueue();

        expect(processed, ["a", "b"]);
        expect(queue.length, 0);
        sub.cancel();
        queue.dispose();
      });

      test("pause during active drain — current event completes, next is held", () async {
        final processed = <String>[];
        final firstStarted = Completer<void>();
        final firstGate = Completer<void>();

        final queue = EventQueue<String>();
        final sub = queue.listen((e) async {
          if (e == "a") {
            firstStarted.complete();
            await firstGate.future;
          }
          processed.add(e);
        });

        queue.enqueue("a");
        queue.enqueue("b");

        await firstStarted.future;
        sub.pause();
        firstGate.complete();
        await pumpEventQueue();

        expect(processed, ["a"]);
        expect(queue.length, 1);

        sub.resume();
        await pumpEventQueue();

        expect(processed, ["a", "b"]);
        queue.dispose();
      });

      test("multiple pause/resume cycles preserve order", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async => processed.add(e));

        // Pause immediately before any enqueue
        sub.pause();
        queue.enqueue("a");
        sub.resume();
        await pumpEventQueue();
        expect(processed, ["a"]);

        sub.pause();
        queue.enqueue("b");
        queue.enqueue("c");
        await pumpEventQueue();
        expect(processed, ["a"]); // no change

        sub.resume();
        await pumpEventQueue();
        expect(processed, ["a", "b", "c"]);

        sub.pause();
        queue.enqueue("d");
        sub.resume();
        await pumpEventQueue();
        expect(processed, ["a", "b", "c", "d"]);

        sub.cancel();
        queue.dispose();
      });

      test("resume when not paused is a no-op", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async => processed.add(e));

        queue.resume(); // should not throw
        queue.enqueue("a");
        await pumpEventQueue();
        expect(processed, ["a"]);
        sub.cancel();
        queue.dispose();
      });

      test("double pause is a no-op", () async {
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async {});

        sub.pause();
        sub.pause(); // already paused — no-op
        expect(queue.isPaused, isTrue);

        sub.resume();
        expect(queue.isPaused, isFalse);
        sub.cancel();
        queue.dispose();
      });

      test("events accumulate during pause and drain in order on resume", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async => processed.add(e));

        sub.pause();
        for (var i = 0; i < 50; i++) {
          queue.enqueue("event-$i");
        }
        expect(queue.length, 50);

        sub.resume();
        await pumpEventQueue(100);

        expect(processed.length, 50);
        for (var i = 0; i < 50; i++) {
          expect(processed[i], "event-$i");
        }
        sub.cancel();
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // maxSize
    // -----------------------------------------------------------------------
    group("maxSize", () {
      test("drops oldest events when maxSize exceeded", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(maxSize: 2);

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c"); // drops "a"
        expect(queue.length, 2);

        queue.listen((e) async => processed.add(e));
        await pumpEventQueue();

        expect(processed, ["b", "c"]);
        queue.dispose();
      });

      test("maxSize 1 keeps only the latest event", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(maxSize: 1);

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c");
        expect(queue.length, 1);

        queue.listen((e) async => processed.add(e));
        await pumpEventQueue();

        expect(processed, ["c"]);
        queue.dispose();
      });

      test("null maxSize allows unlimited events", () {
        final queue = EventQueue<String>();

        for (var i = 0; i < 1000; i++) {
          queue.enqueue("event-$i");
        }
        expect(queue.length, 1000);
        queue.dispose();
      });

      test("maxSize drops oldest from buffer during enqueue", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(maxSize: 3);

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c");
        queue.enqueue("d"); // drops "a"
        queue.enqueue("e"); // drops "b"
        expect(queue.length, 3);

        queue.listen((e) async => processed.add(e));
        await pumpEventQueue();

        expect(processed, ["c", "d", "e"]);
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Error handling & retry
    // -----------------------------------------------------------------------
    group("error handling", () {
      test("onError called when listener throws", () async {
        final errors = <(String, Object)>[];
        final queue = EventQueue<String>();
        queue.listen(
          (e) async => throw Exception("fail"),
          onError: (event, error) => errors.add((event, error)),
        );

        queue.enqueue("a");
        await pumpEventQueue();

        expect(errors, hasLength(1));
        expect(errors.first.$1, "a");
        expect(errors.first.$2, isA<Exception>());
        queue.dispose();
      });

      test("default onError does not throw", () async {
        final queue = EventQueue<String>();
        queue.listen((e) async => throw Exception("oops"));

        queue.enqueue("a");
        await pumpEventQueue(); // should not throw
        queue.dispose();
      });

      test("failed event stays at head for retry on next drain trigger", () async {
        var failCount = 0;
        final processed = <String>[];
        final queue = EventQueue<String>(maxAttempts: 5);
        queue.listen(
          (e) async {
            if (e == "flaky" && failCount < 2) {
              failCount++;
              throw Exception("transient");
            }
            processed.add(e);
          },
          onError: (_, __) {},
        );

        queue.enqueue("flaky");
        await pumpEventQueue();

        queue.enqueue("trigger1");
        await pumpEventQueue();

        queue.enqueue("trigger2");
        await pumpEventQueue();

        expect(failCount, 2);
        expect(processed, contains("flaky"));
        expect(processed, containsAllInOrder(["flaky", "trigger1", "trigger2"]));
        queue.dispose();
      });

      test("poison event dropped after maxAttempts consecutive failures", () async {
        final errorEvents = <String>[];
        final processed = <String>[];
        final queue = EventQueue<String>(maxAttempts: 3);
        queue.listen(
          (e) async {
            if (e == "poison") throw Exception("always fails");
            processed.add(e);
          },
          onError: (event, _) => errorEvents.add(event),
        );

        queue.enqueue("poison");
        queue.enqueue("good");

        await pumpEventQueue();

        queue.enqueue("trigger1");
        await pumpEventQueue();

        queue.enqueue("trigger2");
        await pumpEventQueue();

        expect(errorEvents.where((e) => e == "poison").length, 3);
        expect(processed, contains("good"));
        expect(queue.length, 0);
        queue.dispose();
      });

      test("after poison is dropped, queue continues with next event", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(maxAttempts: 1);
        queue.listen(
          (e) async {
            if (e == "bad") throw Exception("bad");
            processed.add(e);
          },
          onError: (_, __) {},
        );

        queue.enqueue("bad");
        queue.enqueue("good1");
        queue.enqueue("good2");
        await pumpEventQueue();

        expect(processed, ["good1", "good2"]);
        queue.dispose();
      });

      test("attempt counter resets after a successful dequeue", () async {
        var firstAttempts = 0;
        var secondAttempts = 0;
        final processed = <String>[];
        final queue = EventQueue<String>(maxAttempts: 5);
        queue.listen(
          (e) async {
            if (e == "first") {
              firstAttempts++;
              if (firstAttempts < 3) throw Exception("retry");
            }
            if (e == "second") {
              secondAttempts++;
              if (secondAttempts < 3) throw Exception("retry");
            }
            processed.add(e);
          },
          onError: (_, __) {},
        );

        queue.enqueue("first");
        queue.enqueue("second");

        await pumpEventQueue();
        queue.enqueue("t1");
        await pumpEventQueue();
        queue.enqueue("t2");
        await pumpEventQueue();

        expect(processed, contains("first"));

        queue.enqueue("t3");
        await pumpEventQueue();
        queue.enqueue("t4");
        await pumpEventQueue();

        expect(processed, contains("second"));
        queue.dispose();
      });

      test("maxAttempts defaults to 5", () {
        final queue = EventQueue<String>();
        expect(queue.maxAttempts, 5);
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Dispose
    // -----------------------------------------------------------------------
    group("dispose", () {
      test("clears pending events", () {
        final queue = EventQueue<String>();

        queue.enqueue("a");
        queue.enqueue("b");
        expect(queue.length, 2);

        queue.dispose();
        expect(queue.length, 0);
      });

      test("enqueue after dispose is a no-op", () async {
        final processed = <String>[];
        final queue = EventQueue<String>();
        queue.listen((e) async => processed.add(e));

        queue.dispose();
        queue.enqueue("a");
        await pumpEventQueue();

        expect(processed, isEmpty);
        expect(queue.length, 0);
      });

      test("dispose unblocks paused drain and stops processing", () async {
        final processed = <String>[];
        final firstDone = Completer<void>();

        final queue = EventQueue<String>();
        final sub = queue.listen((e) async {
          processed.add(e);
          if (e == "a") firstDone.complete();
        });

        queue.enqueue("a");
        queue.enqueue("b");

        await firstDone.future;

        sub.pause();
        await pumpEventQueue();
        expect(processed, ["a"]);

        queue.dispose();
        await pumpEventQueue();

        expect(processed, ["a"]);
      });

      test("dispose during active drain stops after current event", () async {
        final processed = <String>[];
        final gate = Completer<void>();

        late EventQueue<String> queue;
        queue = EventQueue<String>();
        queue.listen((e) async {
          if (e == "a") {
            await gate.future;
            queue.dispose();
          }
          processed.add(e);
        });

        queue.enqueue("a");
        queue.enqueue("b");

        gate.complete();
        await pumpEventQueue();

        expect(processed, ["a"]);
      });

      test("pause after dispose is a no-op", () {
        final queue = EventQueue<String>();
        queue.dispose();
        queue.pause(); // should not throw
      });
    });

    // -----------------------------------------------------------------------
    // Getters
    // -----------------------------------------------------------------------
    group("getters", () {
      test("length reflects pending event count", () {
        final queue = EventQueue<String>();

        expect(queue.length, 0);
        queue.enqueue("a");
        expect(queue.length, 1);
        queue.enqueue("b");
        expect(queue.length, 2);
        queue.dispose();
      });

      test("isPaused reflects pause state transitions", () {
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async {});

        expect(queue.isPaused, isFalse);
        sub.pause();
        expect(queue.isPaused, isTrue);
        sub.resume();
        expect(queue.isPaused, isFalse);
        sub.cancel();
        queue.dispose();
      });

      test("isPaused is false after dispose even if paused before", () {
        final queue = EventQueue<String>();
        final sub = queue.listen((e) async {});

        sub.pause();
        expect(queue.isPaused, isTrue);
        queue.dispose();
        expect(queue.isPaused, isFalse);
      });

      test("hasListener reflects listener state", () {
        final queue = EventQueue<String>();
        expect(queue.hasListener, isFalse);

        final sub = queue.listen((e) async {});
        expect(queue.hasListener, isTrue);

        sub.cancel();
        expect(queue.hasListener, isFalse);
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Listener replacement (detach + re-attach)
    // -----------------------------------------------------------------------
    group("listener replacement", () {
      test("cancel + listen attaches a new listener for buffered events", () async {
        final log = <String>[];
        final queue = EventQueue<String>();

        queue.enqueue("a"); // buffered
        final sub = queue.listen((e) async => log.add("v2:$e"));
        queue.enqueue("b");

        await pumpEventQueue();

        // Both events processed with v2 listener
        expect(log, ["v2:a", "v2:b"]);
        sub.cancel();
        queue.dispose();
      });

      test("onError is replaced with new listener", () async {
        final errors1 = <String>[];
        final errors2 = <String>[];
        final queue = EventQueue<String>(maxAttempts: 3);

        var sub = queue.listen(
          (e) async => throw Exception("fail"),
          onError: (e, _) => errors1.add(e),
        );

        queue.enqueue("a");
        await pumpEventQueue();
        expect(errors1, ["a"]);

        // Replace listener with new error handler
        sub.cancel();
        sub = queue.listen(
          (e) async => throw Exception("fail"),
          onError: (e, _) => errors2.add(e),
        );
        queue.enqueue("trigger");
        await pumpEventQueue();

        // New errors go to errors2
        expect(errors2, isNotEmpty);
        sub.cancel();
        queue.dispose();
      });

      test("listen throws if subscription already active", () {
        final queue = EventQueue<String>();
        queue.listen((e) async {});

        expect(
          () => queue.listen((e) async {}),
          throwsA(isA<StateError>()),
        );
        queue.dispose();
      });
    });
  });
}

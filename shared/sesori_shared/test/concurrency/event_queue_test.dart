import "dart:async";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

/// Yields to the event loop enough times for the drain loop to process
/// all pending events whose [onDequeue] completes synchronously.
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
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
        );

        queue.enqueue("a");
        await pumpEventQueue();

        expect(processed, ["a"]);
        expect(queue.length, 0);
        queue.dispose();
      });

      test("processes multiple events in FIFO order", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
        );

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c");
        await pumpEventQueue();

        expect(processed, ["a", "b", "c"]);
        expect(queue.length, 0);
        queue.dispose();
      });

      test("events enqueued during onDequeue handler are appended to the queue", () async {
        final processed = <String>[];
        late EventQueue<String> queue;
        queue = EventQueue<String>(
          onDequeue: (e) async {
            processed.add(e);
            if (e == "a") {
              queue.enqueue("d");
            }
          },
        );

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c");
        await pumpEventQueue();

        // "d" is enqueued synchronously during onDequeue("a")'s body —
        // which runs inside enqueue("a") before enqueue("b")/("c") execute.
        // So the actual FIFO order in the internal queue is: a, d, b, c.
        expect(processed, ["a", "d", "b", "c"]);
        queue.dispose();
      });

      test("drain auto-starts on first enqueue", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
        );

        // No explicit drain call needed
        queue.enqueue("x");
        await pumpEventQueue();

        expect(processed, ["x"]);
        queue.dispose();
      });

      test("sequential onDequeue — second event waits for first to finish", () async {
        final order = <String>[];
        final gate = Completer<void>();

        final queue = EventQueue<String>(
          onDequeue: (e) async {
            if (e == "slow") {
              order.add("slow-start");
              await gate.future;
              order.add("slow-end");
            } else {
              order.add(e);
            }
          },
        );

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
    // Pause / Resume
    // -----------------------------------------------------------------------
    group("pause / resume", () {
      test("pause prevents dequeuing", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
        );

        queue.pause();
        queue.enqueue("a");
        queue.enqueue("b");
        await pumpEventQueue();

        expect(processed, isEmpty);
        expect(queue.length, 2);
        expect(queue.isPaused, isTrue);
        queue.dispose();
      });

      test("resume processes the backlog", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
        );

        queue.pause();
        queue.enqueue("a");
        queue.enqueue("b");
        await pumpEventQueue();
        expect(processed, isEmpty);

        queue.resume();
        await pumpEventQueue();

        expect(processed, ["a", "b"]);
        expect(queue.length, 0);
        queue.dispose();
      });

      test("startPaused creates queue in paused state", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
          startPaused: true,
        );

        expect(queue.isPaused, isTrue);
        queue.enqueue("a");
        await pumpEventQueue();
        expect(processed, isEmpty);

        queue.resume();
        await pumpEventQueue();
        expect(processed, ["a"]);
        queue.dispose();
      });

      test("pause during active drain — current event completes, next is held", () async {
        final processed = <String>[];
        final firstStarted = Completer<void>();
        final firstGate = Completer<void>();

        final queue = EventQueue<String>(
          onDequeue: (e) async {
            if (e == "a") {
              firstStarted.complete();
              await firstGate.future;
            }
            processed.add(e);
          },
        );

        queue.enqueue("a");
        queue.enqueue("b");

        // Wait for "a" to begin processing
        await firstStarted.future;

        // Pause while "a" is in-flight
        queue.pause();

        // Let "a" finish
        firstGate.complete();
        await pumpEventQueue();

        // "a" completed, "b" held by pause
        expect(processed, ["a"]);
        expect(queue.length, 1);

        // Resume to drain "b"
        queue.resume();
        await pumpEventQueue();

        expect(processed, ["a", "b"]);
        queue.dispose();
      });

      test("multiple pause/resume cycles preserve order", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
          startPaused: true,
        );

        queue.enqueue("a");
        queue.resume();
        await pumpEventQueue();
        expect(processed, ["a"]);

        queue.pause();
        queue.enqueue("b");
        queue.enqueue("c");
        await pumpEventQueue();
        expect(processed, ["a"]); // no change

        queue.resume();
        await pumpEventQueue();
        expect(processed, ["a", "b", "c"]);

        queue.pause();
        queue.enqueue("d");
        queue.resume();
        await pumpEventQueue();
        expect(processed, ["a", "b", "c", "d"]);

        queue.dispose();
      });

      test("resume when not paused is a no-op", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
        );

        queue.resume(); // should not throw
        queue.enqueue("a");
        await pumpEventQueue();
        expect(processed, ["a"]);
        queue.dispose();
      });

      test("double pause is a no-op", () async {
        final queue = EventQueue<String>(
          onDequeue: (e) async {},
          startPaused: true,
        );

        queue.pause(); // already paused — no-op
        expect(queue.isPaused, isTrue);

        queue.resume();
        expect(queue.isPaused, isFalse);
        queue.dispose();
      });

      test("events accumulate during pause and drain in order on resume", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
        );

        queue.pause();
        for (var i = 0; i < 50; i++) {
          queue.enqueue("event-$i");
        }
        expect(queue.length, 50);

        queue.resume();
        await pumpEventQueue(100);

        expect(processed.length, 50);
        for (var i = 0; i < 50; i++) {
          expect(processed[i], "event-$i");
        }
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // maxSize
    // -----------------------------------------------------------------------
    group("maxSize", () {
      test("drops oldest events when maxSize exceeded", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
          maxSize: 2,
          startPaused: true,
        );

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c"); // drops "a"
        expect(queue.length, 2);

        queue.resume();
        await pumpEventQueue();

        expect(processed, ["b", "c"]);
        queue.dispose();
      });

      test("maxSize 1 keeps only the latest event", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
          maxSize: 1,
          startPaused: true,
        );

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c");
        expect(queue.length, 1);

        queue.resume();
        await pumpEventQueue();

        expect(processed, ["c"]);
        queue.dispose();
      });

      test("null maxSize allows unlimited events", () {
        final queue = EventQueue<String>(
          onDequeue: (e) async {},
          startPaused: true,
        );

        for (var i = 0; i < 1000; i++) {
          queue.enqueue("event-$i");
        }
        expect(queue.length, 1000);
        queue.dispose();
      });

      test("maxSize drops oldest from internal queue during enqueue", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
          maxSize: 3,
          startPaused: true,
        );

        queue.enqueue("a");
        queue.enqueue("b");
        queue.enqueue("c");
        queue.enqueue("d"); // drops "a"
        queue.enqueue("e"); // drops "b"
        expect(queue.length, 3);

        queue.resume();
        await pumpEventQueue();

        expect(processed, ["c", "d", "e"]);
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Error handling & retry
    // -----------------------------------------------------------------------
    group("error handling", () {
      test("onError called when onDequeue throws", () async {
        final errors = <(String, Object)>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => throw Exception("fail"),
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
        // Uses the built-in _defaultOnError — should just print
        final queue = EventQueue<String>(
          onDequeue: (e) async => throw Exception("oops"),
        );

        queue.enqueue("a");
        await pumpEventQueue(); // should not throw
        queue.dispose();
      });

      test("failed event stays at head for retry on next drain trigger", () async {
        var failCount = 0;
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async {
            if (e == "flaky" && failCount < 2) {
              failCount++;
              throw Exception("transient");
            }
            processed.add(e);
          },
          onError: (_, __) {},
          maxAttempts: 5,
        );

        queue.enqueue("flaky");
        await pumpEventQueue();
        // Attempt 1 fails, drain breaks — "flaky" still at head

        queue.enqueue("trigger1");
        await pumpEventQueue();
        // Attempt 2 fails, drain breaks

        queue.enqueue("trigger2");
        await pumpEventQueue();
        // Attempt 3 succeeds (failCount == 2)

        expect(failCount, 2);
        expect(processed, contains("flaky"));
        expect(processed, containsAllInOrder(["flaky", "trigger1", "trigger2"]));
        queue.dispose();
      });

      test("poison event dropped after maxAttempts consecutive failures", () async {
        final errorEvents = <String>[];
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async {
            if (e == "poison") throw Exception("always fails");
            processed.add(e);
          },
          onError: (event, _) => errorEvents.add(event),
          maxAttempts: 3,
        );

        queue.enqueue("poison");
        queue.enqueue("good");

        // Attempt 1: drain starts, "poison" fails, drain breaks
        await pumpEventQueue();

        // Attempt 2: trigger new drain
        queue.enqueue("trigger1");
        await pumpEventQueue();

        // Attempt 3: trigger new drain — maxAttempts reached, poison dropped
        queue.enqueue("trigger2");
        await pumpEventQueue();

        // "poison" dropped; remaining events processed
        expect(errorEvents.where((e) => e == "poison").length, 3);
        expect(processed, contains("good"));
        expect(queue.length, 0);
        queue.dispose();
      });

      test("after poison is dropped, queue continues with next event", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async {
            if (e == "bad") throw Exception("bad");
            processed.add(e);
          },
          onError: (_, __) {},
          maxAttempts: 1, // drop immediately on first failure
        );

        queue.enqueue("bad");
        queue.enqueue("good1");
        queue.enqueue("good2");
        await pumpEventQueue();

        // "bad" fails once → maxAttempts(1) reached → dropped → continue with rest
        expect(processed, ["good1", "good2"]);
        queue.dispose();
      });

      test("attempt counter resets after a successful dequeue", () async {
        // First event fails twice then succeeds; second event should get fresh counter
        var firstAttempts = 0;
        var secondAttempts = 0;
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async {
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
          maxAttempts: 5,
        );

        queue.enqueue("first");
        queue.enqueue("second");

        // Pump through retries for "first" (needs 2 extra triggers)
        await pumpEventQueue();
        queue.enqueue("t1");
        await pumpEventQueue();
        queue.enqueue("t2");
        await pumpEventQueue();

        // "first" eventually succeeds, then "second" starts with fresh counter
        expect(processed, contains("first"));

        // Pump through retries for "second"
        queue.enqueue("t3");
        await pumpEventQueue();
        queue.enqueue("t4");
        await pumpEventQueue();

        expect(processed, contains("second"));
        queue.dispose();
      });

      test("maxAttempts defaults to 5", () {
        final queue = EventQueue<String>(onDequeue: (e) async {});
        expect(queue.maxAttempts, 5);
        queue.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Dispose
    // -----------------------------------------------------------------------
    group("dispose", () {
      test("clears pending events", () {
        final queue = EventQueue<String>(
          onDequeue: (e) async {},
          startPaused: true,
        );

        queue.enqueue("a");
        queue.enqueue("b");
        expect(queue.length, 2);

        queue.dispose();
        expect(queue.length, 0);
      });

      test("enqueue after dispose is a no-op", () async {
        final processed = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => processed.add(e),
        );

        queue.dispose();
        queue.enqueue("a");
        await pumpEventQueue();

        expect(processed, isEmpty);
        expect(queue.length, 0);
      });

      test("dispose unblocks paused drain and stops processing", () async {
        final processed = <String>[];
        final firstDone = Completer<void>();

        final queue = EventQueue<String>(
          onDequeue: (e) async {
            processed.add(e);
            if (e == "a") firstDone.complete();
          },
        );

        queue.enqueue("a");
        queue.enqueue("b");

        // Wait for "a" to be processed
        await firstDone.future;

        // Pause — "b" is held
        queue.pause();
        await pumpEventQueue();
        expect(processed, ["a"]);

        // Dispose while paused — should unblock drain, not process "b"
        queue.dispose();
        await pumpEventQueue();

        expect(processed, ["a"]);
      });

      test("dispose during active drain stops after current event", () async {
        final processed = <String>[];
        final gate = Completer<void>();

        late EventQueue<String> queue;
        queue = EventQueue<String>(
          onDequeue: (e) async {
            if (e == "a") {
              await gate.future;
              queue.dispose(); // dispose mid-drain
            }
            processed.add(e);
          },
        );

        queue.enqueue("a");
        queue.enqueue("b");

        gate.complete();
        await pumpEventQueue();

        // "a" handler ran (added after dispose call), "b" should NOT be processed
        // because _disposed is true when the loop re-checks
        expect(processed, ["a"]);
      });

      test("pause after dispose is a no-op", () {
        final queue = EventQueue<String>(onDequeue: (e) async {});
        queue.dispose();
        queue.pause(); // should not throw
      });
    });

    // -----------------------------------------------------------------------
    // Getters
    // -----------------------------------------------------------------------
    group("getters", () {
      test("length reflects pending event count", () {
        final queue = EventQueue<String>(
          onDequeue: (e) async {},
          startPaused: true,
        );

        expect(queue.length, 0);
        queue.enqueue("a");
        expect(queue.length, 1);
        queue.enqueue("b");
        expect(queue.length, 2);
        queue.dispose();
      });

      test("isPaused reflects pause state transitions", () {
        final queue = EventQueue<String>(onDequeue: (e) async {});

        expect(queue.isPaused, isFalse);
        queue.pause();
        expect(queue.isPaused, isTrue);
        queue.resume();
        expect(queue.isPaused, isFalse);
        queue.dispose();
      });

      test("isPaused is false after dispose even if paused before", () {
        final queue = EventQueue<String>(
          onDequeue: (e) async {},
          startPaused: true,
        );

        expect(queue.isPaused, isTrue);
        queue.dispose();
        expect(queue.isPaused, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Callback replacement
    // -----------------------------------------------------------------------
    group("mutable callbacks", () {
      test("onDequeue can be replaced at runtime", () async {
        final log = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => log.add("v1:$e"),
          startPaused: true,
        );

        queue.enqueue("a");
        queue.onDequeue = (e) async => log.add("v2:$e");
        queue.enqueue("b");

        queue.resume();
        await pumpEventQueue();

        // Both events processed with v2 handler since drain hadn't started
        expect(log, ["v2:a", "v2:b"]);
        queue.dispose();
      });

      test("onError can be replaced at runtime", () async {
        final errors1 = <String>[];
        final errors2 = <String>[];
        final queue = EventQueue<String>(
          onDequeue: (e) async => throw Exception("fail"),
          onError: (e, _) => errors1.add(e),
          maxAttempts: 3,
        );

        queue.enqueue("a");
        await pumpEventQueue();
        expect(errors1, ["a"]);

        // Replace error handler
        queue.onError = (e, _) => errors2.add(e);
        queue.enqueue("trigger");
        await pumpEventQueue();

        // Second error goes to errors2
        expect(errors2.where((e) => e == "a"), hasLength(1));
        queue.dispose();
      });
    });
  });
}

import "dart:async";
import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("EventQueue", () {
    group("basic drain", () {
      test("enqueued events are dequeued in FIFO order", () async {
        final dequeued = <SesoriSseEvent>[];
        final queue = EventQueue<SesoriSseEvent>(onDequeue: (event) async => dequeued.add(event));

        final first = _event("a");
        final second = _event("b");
        final third = _event("c");
        queue.enqueue(first);
        queue.enqueue(second);
        queue.enqueue(third);

        await _pumpEventLoop();

        expect(dequeued, equals([first, second, third]));
        expect(queue.length, equals(0));
      });

      test("drain starts automatically on first enqueue", () async {
        final dequeued = <SesoriSseEvent>[];
        final queue = EventQueue<SesoriSseEvent>(onDequeue: (event) async => dequeued.add(event));

        final event = _event("x");
        queue.enqueue(event);
        await _pumpEventLoop();

        expect(dequeued, equals([event]));
      });

      test("dequeue callback can serialize payload envelope", () async {
        final envelopes = <String>[];
        final queue = EventQueue<SesoriSseEvent>(
          onDequeue: (event) async {
            envelopes.add(jsonEncode({"payload": event.toJson()}));
          },
        );

        final event = _event("serialized");
        queue.enqueue(event);
        await _pumpEventLoop();

        expect(
          jsonDecode(envelopes.single) as Map<String, dynamic>,
          equals({"payload": event.toJson()}),
        );
      });

      test("events enqueued during drain are picked up", () async {
        final dequeued = <SesoriSseEvent>[];
        late EventQueue queue;
        final first = _event("first");
        final second = _event("second");

        queue = EventQueue<SesoriSseEvent>(
          onDequeue: (event) async {
            dequeued.add(event);
            if (identical(event, first)) {
              queue.enqueue(second);
            }
          },
        );

        queue.enqueue(first);
        await _pumpEventLoop();

        expect(dequeued, equals([first, second]));
      });

      test("onDequeue error keeps the failed event at the head", () async {
        final dequeued = <SesoriSseEvent>[];
        final good = _event("good");
        final bad = _event("bad");
        final after = _event("after");

        final queue = EventQueue<SesoriSseEvent>(
          onDequeue: (event) async {
            if (identical(event, bad)) throw Exception("fail");
            dequeued.add(event);
          },
          onError: (_, _) {},
        );

        queue.enqueue(good);
        queue.enqueue(bad);
        queue.enqueue(after);
        await _pumpEventLoop();

        expect(dequeued, equals([good]));
        expect(queue.length, equals(2));
      });

      test("poisoned event is dropped after maxAttempts", () async {
        final dequeued = <SesoriSseEvent>[];
        final errors = <SesoriSseEvent>[];
        final poison = _event("poison");
        final healthy = _event("healthy");

        final queue = EventQueue<SesoriSseEvent>(
          onDequeue: (event) async {
            if (identical(event, poison)) throw Exception("fail");
            dequeued.add(event);
          },
          onError: (event, _) => errors.add(event),
          maxAttempts: 3,
        );

        queue.enqueue(poison);
        queue.enqueue(healthy);
        await _pumpEventLoop();
        expect(queue.length, equals(2));

        queue.enqueue(_event("trigger2"));
        await _pumpEventLoop();
        expect(queue.length, equals(3));

        final trigger3 = _event("trigger3");
        queue.enqueue(trigger3);
        await _pumpEventLoop();

        expect(errors.where((event) => identical(event, poison)), hasLength(3));
        expect(dequeued, contains(healthy));
        expect(dequeued, contains(trigger3));
        expect(queue.length, equals(0));
      });
    });

    group("maxSize", () {
      test("oldest events are dropped when maxSize is exceeded", () async {
        final dequeued = <SesoriSseEvent>[];
        final queue = EventQueue<SesoriSseEvent>(
          onDequeue: (event) async => dequeued.add(event),
          maxSize: 3,
          startPaused: true,
        );

        final c = _event("c");
        final d = _event("d");
        final e = _event("e");
        queue.enqueue(_event("a"));
        queue.enqueue(_event("b"));
        queue.enqueue(c);
        queue.enqueue(d);
        queue.enqueue(e);

        expect(queue.length, equals(3));
        queue.resume();
        await _pumpEventLoop();

        expect(dequeued, equals([c, d, e]));
      });
    });

    group("pause / resume", () {
      test("pause prevents dequeuing and resume drains backlog", () async {
        final dequeued = <SesoriSseEvent>[];
        final queue = EventQueue<SesoriSseEvent>(onDequeue: (event) async => dequeued.add(event));

        final before = _event("before");
        final during = _event("during");
        queue.enqueue(before);
        await _pumpEventLoop();
        expect(dequeued, equals([before]));

        queue.pause();
        queue.enqueue(during);
        await _pumpEventLoop();

        expect(dequeued, equals([before]));
        expect(queue.length, equals(1));

        queue.resume();
        await _pumpEventLoop();
        expect(dequeued, equals([before, during]));
      });

      test("startPaused holds events until resume", () async {
        final dequeued = <SesoriSseEvent>[];
        final queue = EventQueue<SesoriSseEvent>(
          onDequeue: (event) async => dequeued.add(event),
          startPaused: true,
        );

        final held = _event("held");
        queue.enqueue(held);
        await _pumpEventLoop();
        expect(dequeued, isEmpty);

        queue.resume();
        await _pumpEventLoop();
        expect(dequeued, equals([held]));
      });
    });

    group("dispose", () {
      test("dispose clears pending events", () {
        final queue = EventQueue<SesoriSseEvent>(onDequeue: (event) async {}, startPaused: true);

        queue.enqueue(_event("a"));
        queue.enqueue(_event("b"));
        expect(queue.length, equals(2));

        queue.dispose();
        expect(queue.length, equals(0));
      });

      test("enqueue after dispose is a no-op", () async {
        final dequeued = <SesoriSseEvent>[];
        final queue = EventQueue<SesoriSseEvent>(onDequeue: (event) async => dequeued.add(event));

        queue.dispose();
        queue.enqueue(_event("ghost"));
        await _pumpEventLoop();

        expect(queue.length, equals(0));
        expect(dequeued, isEmpty);
      });
    });

    group("onDequeue swap", () {
      test("changing onDequeue before resume uses the new callback", () async {
        final log = <String>[];
        final queue = EventQueue<SesoriSseEvent>(
          onDequeue: (_) async => log.add("v1"),
          startPaused: true,
        );

        queue.enqueue(_event("a"));
        queue.enqueue(_event("b"));
        queue.onDequeue = (_) async => log.add("v2");

        queue.resume();
        await _pumpEventLoop();

        expect(log, equals(["v2", "v2"]));
      });
    });
  });
}

SesoriSseEvent _event(String worktree) {
  return SesoriSseEvent.projectsSummary(
    projects: [
      ProjectActivitySummary(id: worktree, activeSessionIds: const ["s1"]),
    ],
  );
}

Future<void> _pumpEventLoop() => Future<void>.delayed(const Duration(milliseconds: 10));

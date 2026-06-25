import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/concurrency/impl/message_queue.dart";

void main() {
  group("CompleterWithTimeout", () {
    test("completes normally before timeout expires", () async {
      final completer = Completer<String>();
      completer.setTimeout(const Duration(seconds: 2));

      completer.complete("success");
      final result = await completer.future;

      expect(result, equals("success"));
    });

    test("throws TimeoutException when timeout expires before completion", () {
      fakeAsync((async) {
        final completer = Completer<String>();
        completer.setTimeout(const Duration(milliseconds: 100));

        Object? caughtError;
        completer.future.catchError((Object e) {
          caughtError = e;
          return "";
        });

        async.elapse(const Duration(milliseconds: 150));

        expect(caughtError, isA<TimeoutException>());
      });
    });

    test("calls onTimeout callback when timeout expires", () {
      fakeAsync((async) {
        final completer = Completer<String>();
        var timeoutCalled = false;

        completer.setTimeout(
          const Duration(milliseconds: 100),
          onTimeout: () {
            timeoutCalled = true;
          },
        );

        completer.future.catchError((_) => "");

        async.elapse(const Duration(milliseconds: 150));

        expect(timeoutCalled, isTrue);
      });
    });

    test("completes with returnOnTimeout value when provided", () {
      fakeAsync((async) {
        final completer = Completer<String>();
        completer.setTimeout(
          const Duration(milliseconds: 100),
          returnOnTimeout: "timeout_value",
        );

        late String result;
        completer.future.then((v) => result = v);

        async.elapse(const Duration(milliseconds: 150));

        expect(result, equals("timeout_value"));
      });
    });

    test("safeComplete does not throw when already completed", () async {
      final completer = Completer<String>();
      completer.complete("first");

      completer.safeComplete("second");

      final result = await completer.future;
      expect(result, equals("first"));
    });

    test("safeComplete completes when not yet completed", () async {
      final completer = Completer<String>();

      completer.safeComplete("value");

      final result = await completer.future;
      expect(result, equals("value"));
    });
  });

  group("MessageQueue", () {
    test("processes messages sequentially in order", () async {
      final processedOrder = <int>[];
      final gates = <Completer<void>>[];

      final queue = MessageQueue<int, int>(
        sendFunction: (message) async {
          processedOrder.add(message);
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
          return message * 2;
        },
      );

      final future1 = queue.enqueueMessage(1);
      final future2 = queue.enqueueMessage(2);
      final future3 = queue.enqueueMessage(3);

      await pumpEventQueue();
      expect(gates.length, 1, reason: "only first message started");
      gates[0].complete();

      await pumpEventQueue();
      expect(gates.length, 2);
      gates[1].complete();

      await pumpEventQueue();
      expect(gates.length, 3);
      gates[2].complete();

      final result1 = await future1;
      final result2 = await future2;
      final result3 = await future3;

      expect(processedOrder, equals([1, 2, 3]));
      expect(result1, equals(2));
      expect(result2, equals(4));
      expect(result3, equals(6));
    });

    test("handles concurrent enqueue calls from multiple callers", () async {
      final processedMessages = <int>[];
      final queue = MessageQueue<int, int>(
        sendFunction: (message) async {
          processedMessages.add(message);
          return message * 10;
        },
      );

      final futures = <Future<int>>[];
      for (int i = 1; i <= 5; i++) {
        futures.add(queue.enqueueMessage(i));
      }

      final results = await Future.wait(futures);

      expect(processedMessages, equals([1, 2, 3, 4, 5]));
      expect(results, equals([10, 20, 30, 40, 50]));
    });

    test("propagates errors from handler to caller", () async {
      final queue = MessageQueue<int, int>(
        sendFunction: (message) async {
          if (message == 2) {
            throw Exception("Handler error for message 2");
          }
          return message * 2;
        },
      );

      final future1 = queue.enqueueMessage(1);
      final future2 = queue.enqueueMessage(2);
      final future3 = queue.enqueueMessage(3);

      final result1 = await future1;
      expect(result1, equals(2));

      expect(
        future2,
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            "message",
            contains("Handler error for message 2"),
          ),
        ),
      );

      final result3 = await future3;
      expect(result3, equals(6));
    });

    test("queue becomes idle after all messages are processed", () async {
      var isProcessing = false;
      final queue = MessageQueue<int, int>(
        sendFunction: (message) async {
          isProcessing = true;
          isProcessing = false;
          return message;
        },
      );

      final future1 = queue.enqueueMessage(1);
      final future2 = queue.enqueueMessage(2);

      await future1;
      await future2;
      await pumpEventQueue();

      expect(isProcessing, isFalse);
    });

    test("respects inFlightTimeout and completes with timeout error", () {
      fakeAsync((async) {
        final queue = MessageQueue<int, int>(
          sendFunction: (message) async {
            await Completer<void>().future; // never completes
            return message * 2;
          },
          inFlightTimeout: const Duration(milliseconds: 200),
        );

        Object? caughtError;
        queue.enqueueMessage(1).catchError((Object e) {
          caughtError = e;
          return 0;
        });

        async.elapse(const Duration(milliseconds: 300));

        expect(caughtError, isA<TimeoutException>());
      });
    });

    test("waits for isReady completer before processing messages", () async {
      final readyCompleter = Completer<void>();
      var messageProcessed = false;

      final queue = MessageQueue<int, int>(
        sendFunction: (message) async {
          messageProcessed = true;
          return message;
        },
        isReady: readyCompleter,
      );

      unawaited(queue.enqueueMessage(1));

      await pumpEventQueue();
      expect(messageProcessed, isFalse);

      readyCompleter.complete();

      await pumpEventQueue();
      expect(messageProcessed, isTrue);
    });

    test("handles synchronous sendFunction", () async {
      final queue = MessageQueue<int, int>(
        sendFunction: (message) {
          return message * 3;
        },
      );

      final future1 = queue.enqueueMessage(2);
      final future2 = queue.enqueueMessage(3);

      final result1 = await future1;
      final result2 = await future2;

      expect(result1, equals(6));
      expect(result2, equals(9));
    });

    test("processes messages even when enqueued rapidly", () async {
      final processedMessages = <int>[];
      final queue = MessageQueue<int, int>(
        sendFunction: (message) async {
          processedMessages.add(message);
          return message;
        },
      );

      for (int i = 1; i <= 10; i++) {
        unawaited(queue.enqueueMessage(i));
      }

      await pumpEventQueue();

      expect(processedMessages, equals(List.generate(10, (i) => i + 1)));
    });

    test("returns correct futures for each enqueued message", () async {
      final queue = MessageQueue<String, String>(
        sendFunction: (message) async {
          return message.toUpperCase();
        },
      );

      final future1 = queue.enqueueMessage("hello");
      final future2 = queue.enqueueMessage("world");
      final future3 = queue.enqueueMessage("test");

      final result1 = await future1;
      final result2 = await future2;
      final result3 = await future3;

      expect(result1, equals("HELLO"));
      expect(result2, equals("WORLD"));
      expect(result3, equals("TEST"));
    });
  });
}

import "package:sesori_dart_core/src/cubits/session_detail/prompt_send_queue.dart";
import "package:test/test.dart";

void main() {
  group("PromptSendQueue", () {
    late PromptSendQueue queue;

    setUp(() => queue = PromptSendQueue());

    test("starts empty", () {
      expect(queue.isEmpty, isTrue);
      expect(queue.isNotEmpty, isFalse);
      expect(queue.items, isEmpty);
    });

    test("enqueue adds to the end", () {
      queue.enqueue("first");
      queue.enqueue("second");
      expect(queue.items, ["first", "second"]);
      expect(queue.isEmpty, isFalse);
      expect(queue.isNotEmpty, isTrue);
    });

    test("cancel removes duplicate-valued messages by position, not value", () {
      queue.enqueue("same");
      queue.enqueue("same");
      queue.enqueue("other");
      expect(queue.cancel(0), "same");
      // Only the first "same" is removed; the second remains.
      expect(queue.items, ["same", "other"]);
    });

    test("dequeue removes from the front", () {
      queue.enqueue("a");
      queue.enqueue("b");
      expect(queue.dequeue(), "a");
      expect(queue.items, ["b"]);
    });

    test("dequeue returns null when empty", () {
      expect(queue.dequeue(), isNull);
    });

    test("requeue inserts at the front", () {
      queue.enqueue("existing");
      queue.requeue("retried");
      expect(queue.items, ["retried", "existing"]);
    });

    test("cancel removes by index and returns the message", () {
      queue.enqueue("a");
      queue.enqueue("b");
      queue.enqueue("c");
      expect(queue.cancel(1), "b");
      expect(queue.items, ["a", "c"]);
    });

    test("cancel returns null for negative index", () {
      queue.enqueue("a");
      expect(queue.cancel(-1), isNull);
      expect(queue.items, ["a"]);
    });

    test("cancel returns null for out-of-bounds index", () {
      queue.enqueue("a");
      expect(queue.cancel(5), isNull);
      expect(queue.items, ["a"]);
    });

    test("cancel returns null when empty", () {
      expect(queue.cancel(0), isNull);
    });

    test("items returns an unmodifiable copy", () {
      queue.enqueue("a");
      final items = queue.items;
      expect(() => items.add("b"), throwsUnsupportedError);
    });

    test("full cycle: enqueue, dequeue, requeue, dequeue", () {
      queue.enqueue("msg1");
      queue.enqueue("msg2");

      // Dequeue first — simulate send.
      final sent = queue.dequeue();
      expect(sent, "msg1");

      // Simulate failure — requeue.
      queue.requeue(sent!);
      expect(queue.items, ["msg1", "msg2"]);

      // Retry succeeds.
      expect(queue.dequeue(), "msg1");
      expect(queue.items, ["msg2"]);
    });
  });
}

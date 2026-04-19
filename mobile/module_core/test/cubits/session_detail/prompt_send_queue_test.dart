import "package:sesori_dart_core/src/cubits/session_detail/prompt_send_queue.dart";
import "package:sesori_dart_core/src/cubits/session_detail/queued_session_submission.dart";
import "package:test/test.dart";

const _first = QueuedSessionSubmission(text: "first");
const _second = QueuedSessionSubmission(text: "second");
const _same = QueuedSessionSubmission(text: "same");
const _other = QueuedSessionSubmission(text: "other");
const _a = QueuedSessionSubmission(text: "a");
const _b = QueuedSessionSubmission(text: "b");
const _c = QueuedSessionSubmission(text: "c");
const _existing = QueuedSessionSubmission(text: "existing");
const _retried = QueuedSessionSubmission(text: "retried");
const _msg1 = QueuedSessionSubmission(text: "msg1");
const _msg2 = QueuedSessionSubmission(text: "msg2");

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
      queue.enqueue(_first);
      queue.enqueue(_second);
      expect(queue.items.map((e) => e.displayText), ["first", "second"]);
      expect(queue.isEmpty, isFalse);
      expect(queue.isNotEmpty, isTrue);
    });

    test("cancel removes duplicate-valued messages by position, not value", () {
      queue.enqueue(_same);
      queue.enqueue(_same);
      queue.enqueue(_other);
      final removed = queue.cancel(0);
      expect(removed?.displayText, "same");
      // Only the first "same" is removed; the second remains.
      expect(queue.items.map((e) => e.displayText), ["same", "other"]);
    });

    test("dequeue removes from the front", () {
      queue.enqueue(_a);
      queue.enqueue(_b);
      expect(queue.dequeue()?.displayText, "a");
      expect(queue.items.map((e) => e.displayText), ["b"]);
    });

    test("dequeue returns null when empty", () {
      expect(queue.dequeue(), isNull);
    });

    test("requeue inserts at the front", () {
      queue.enqueue(_existing);
      queue.requeue(_retried);
      expect(queue.items.map((e) => e.displayText), ["retried", "existing"]);
    });

    test("cancel removes by index and returns the message", () {
      queue.enqueue(_a);
      queue.enqueue(_b);
      queue.enqueue(_c);
      expect(queue.cancel(1)?.displayText, "b");
      expect(queue.items.map((e) => e.displayText), ["a", "c"]);
    });

    test("cancel returns null for negative index", () {
      queue.enqueue(_a);
      expect(queue.cancel(-1), isNull);
      expect(queue.items.map((e) => e.displayText), ["a"]);
    });

    test("cancel returns null for out-of-bounds index", () {
      queue.enqueue(_a);
      expect(queue.cancel(5), isNull);
      expect(queue.items.map((e) => e.displayText), ["a"]);
    });

    test("cancel returns null when empty", () {
      expect(queue.cancel(0), isNull);
    });

    test("items returns an unmodifiable copy", () {
      queue.enqueue(_a);
      final items = queue.items;
      expect(() => items.add(_b), throwsUnsupportedError);
    });

    test("full cycle: enqueue, dequeue, requeue, dequeue", () {
      queue.enqueue(_msg1);
      queue.enqueue(_msg2);

      // Dequeue first — simulate send.
      final sent = queue.dequeue();
      expect(sent?.displayText, "msg1");

      // Simulate failure — requeue.
      queue.requeue(sent!);
      expect(queue.items.map((e) => e.displayText), ["msg1", "msg2"]);

      // Retry succeeds.
      expect(queue.dequeue()?.displayText, "msg1");
      expect(queue.items.map((e) => e.displayText), ["msg2"]);
    });
  });
}

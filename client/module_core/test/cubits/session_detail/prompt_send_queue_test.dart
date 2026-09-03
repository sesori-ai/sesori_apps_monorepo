import "package:sesori_dart_core/src/cubits/session_detail/prompt_send_queue.dart";
import "package:sesori_dart_core/src/cubits/session_detail/queued_session_submission.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:test/test.dart";

const _first = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "first",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _second = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "second",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _same = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "same",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _other = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "other",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _a = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "a",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _b = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "b",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _c = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "c",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _existing = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "existing",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _retried = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "retried",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _msg1 = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "msg1",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _msg2 = QueuedSessionSubmission.text(
  promptId: "prompt-1",
  attachments: [],
  text: "msg2",
  inputMode: ComposerInputMode.typed,
  agent: "coder",
  agentModel: null,
);
const _command = QueuedSessionSubmission.command(
  promptId: "command-1",
  text: "src",
  command: "review",
  agent: "coder",
  agentModel: null,
);

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

    test("beginSend moves the front submission into the active slot", () {
      queue.enqueue(_a);
      queue.enqueue(_b);
      expect(queue.beginSend()?.displayText, "a");
      expect(queue.active?.displayText, "a");
      expect(queue.items.map((e) => e.displayText), ["b"]);
      expect(queue.isSending, isTrue);
    });

    test("beginSend returns null when empty", () {
      expect(queue.beginSend(), isNull);
    });

    test("beginSend returns null while another submission is active", () {
      queue.enqueue(_a);
      queue.enqueue(_b);
      queue.beginSend();

      expect(queue.beginSend(), isNull);
      expect(queue.active?.displayText, "a");
      expect(queue.items.map((e) => e.displayText), ["b"]);
    });

    test("completeSend clears the active submission", () {
      queue.enqueue(_a);
      queue.beginSend();

      queue.completeSend();

      expect(queue.active, isNull);
      expect(queue.isSending, isFalse);
    });

    test("failSend restores the active submission at the front", () {
      queue.enqueue(_retried);
      queue.enqueue(_existing);
      queue.beginSend();

      queue.failSend();

      expect(queue.active, isNull);
      expect(queue.items.map((e) => e.displayText), ["retried", "existing"]);
    });

    test("replacePending preserves FIFO while updating selections", () {
      queue.enqueue(_a);
      queue.enqueue(_b);

      queue.replacePending(
        update: (submission) => submission.withSelection(agent: "agent", agentModel: submission.agentModel),
      );

      expect(queue.items.map((item) => item.displayText), ["a", "b"]);
      expect(queue.items.map((item) => item.agent), everyElement("agent"));
    });

    test("an unavailable command stays at the head without being sent", () {
      queue.enqueue(_command);
      queue.enqueue(_a);

      queue.markCommandUnavailable(promptId: _command.promptId);

      expect(queue.items.first, isA<UnavailableQueuedCommandSubmission>());
      expect(queue.items.map((item) => item.displayText), ["/review src", "a"]);
      expect(queue.beginSend(), isNull);
      expect(queue.cancel(0), isA<UnavailableQueuedCommandSubmission>());
      expect(queue.beginSend(), same(_a));
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

    test("cancelling a pending item does not include the active submission in its index", () {
      queue.enqueue(_a);
      queue.enqueue(_b);
      queue.enqueue(_c);
      queue.beginSend();

      expect(queue.cancel(0)?.displayText, "b");
      expect(queue.active?.displayText, "a");
      expect(queue.items.map((e) => e.displayText), ["c"]);
    });

    test("full cycle: enqueue, begin, fail, begin, complete", () {
      queue.enqueue(_msg1);
      queue.enqueue(_msg2);

      final sent = queue.beginSend();
      expect(sent?.displayText, "msg1");

      queue.failSend();
      expect(queue.items.map((e) => e.displayText), ["msg1", "msg2"]);

      expect(queue.beginSend()?.displayText, "msg1");
      queue.completeSend();
      expect(queue.items.map((e) => e.displayText), ["msg2"]);
      expect(queue.active, isNull);
    });
  });
}

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

final _monday = DateTime(2026, 9, 21, 9).millisecondsSinceEpoch;
final _tuesday = DateTime(2026, 9, 22, 23, 50).millisecondsSinceEpoch;
final _wednesday = DateTime(2026, 9, 23, 0, 10).millisecondsSinceEpoch;

MessageWithParts _user({required String id, int? at, List<MessagePart>? parts}) => MessageWithParts(
  info: Message.user(
    id: id,
    sessionID: "s",
    agent: null,
    time: at == null ? null : MessageTime(created: at, completed: null),
    promptId: null,
  ),
  parts: parts ?? [_text(text: "Prompt $id")],
);

/// A user message the list hides: no text and no known file.
MessageWithParts _hiddenUser({required String id}) => _user(id: id, parts: const []);

MessageWithParts _agent({required String id, required MessagePart part, MessageSender sender = MessageSender.agent}) =>
    MessageWithParts(
      info: Message.assistant(
        id: id,
        sessionID: "s",
        agent: null,
        modelID: null,
        providerID: null,
        sender: sender,
        time: null,
      ),
      parts: [part],
    );

/// An agent reply that ends in an answer, so the next user message opens a turn.
MessageWithParts _answer({required String id}) => _agent(
  id: id,
  part: _text(text: "Done."),
);

MessageWithParts _automation({required String id}) => _agent(
  id: id,
  part: _text(text: "Task finished"),
  sender: MessageSender.system,
);

/// An agent reply that ends mid-step, so the next user message is a follow-up.
MessageWithParts _working({required String id}) => _agent(
  id: id,
  part: const MessagePart.tool(
    id: "tool",
    sessionID: "s",
    messageID: "m",
    tool: "read",
    state: ToolState(status: ToolStatus.running, title: null, shellCommand: null, output: null, error: null),
  ),
);

MessagePart _text({required String text}) => MessagePart.text(id: "text", sessionID: "s", messageID: "m", text: text);

MessagePart _file({required String? filename}) => MessagePart.file(
  id: "file",
  sessionID: "s",
  messageID: "m",
  attachment: MessageAttachment.metadata(mime: "image/png", filename: filename),
);

TranscriptPromptList _list({
  required List<MessageWithParts> messages,
  bool hasOlderMessages = false,
  int? userMessagesBefore,
}) => const TranscriptPromptListBuilder().build(
  messages: messages,
  turns: const TranscriptTurnBuilder().build(messages: messages, hasOlderMessages: hasOlderMessages),
  userMessagesBefore: userMessagesBefore,
);

/// `u1` per opener and `  u2<u1` per follow-up, in list order.
List<String> _shape({required TranscriptPromptList list}) => [
  for (final entry in list.entries)
    switch (entry) {
      TranscriptPromptOpener() => entry.messageId,
      TranscriptPromptFollowUp(:final openerMessageId) => "  ${entry.messageId}<$openerMessageId",
    },
];

Iterable<DateTime?> _days({required TranscriptPromptList list}) => list.entries.map((entry) => entry.dayKey);

void main() {
  group("TranscriptPromptListBuilder", () {
    test("lists openers and their follow-ups in the transcript's order, each child below its opener", () {
      final list = _list(
        messages: [
          _user(id: "u1"),
          _working(id: "a1"),
          _user(id: "u2"),
          _user(id: "u3"),
          _answer(id: "a2"),
          _user(id: "u4"),
          _working(id: "a4"),
          _user(id: "u5"),
          _answer(id: "a5"),
        ],
      );

      expect(_shape(list: list), ["u1", "  u2<u1", "  u3<u1", "u4", "  u5<u4"]);
      expect(list.promptCount, 5);
      expect(list.hasTimes, isFalse);
    });

    test("lists prompts before the first opener as openers and never lists automation", () {
      final list = _list(
        hasOlderMessages: true,
        messages: [
          _working(id: "a0"),
          _user(id: "u0"),
          _automation(id: "x1"),
          _answer(id: "a1"),
          _user(id: "u1"),
        ],
      );

      expect(_shape(list: list), ["u0", "u1"]);
    });

    test("numbers every user message from the bridge's count, hidden ones included", () {
      final messages = [
        _user(id: "u1"),
        _answer(id: "a1"),
        _hiddenUser(id: "h1"),
        _automation(id: "x1"),
        _user(id: "u2"),
      ];

      final numbered = _list(messages: messages, userMessagesBefore: 10);
      expect(_shape(list: numbered), ["u1", "u2"]);
      expect(numbered.entries.map((entry) => entry.number), [11, 13]);

      final unnumbered = _list(messages: messages, userMessagesBefore: null);
      expect(unnumbered.entries.map((entry) => entry.number), [null, null]);
    });

    test("reads the whole text, else the first attachment's name, and one line of it", () {
      final list = _list(
        messages: [
          _user(
            id: "u1",
            parts: [
              _text(text: "\n  Fix the build  \nthen deploy"),
              _text(text: "Thanks"),
            ],
          ),
          _answer(id: "a1"),
          _user(
            id: "u2",
            parts: [
              _file(filename: " screen.png "),
              _file(filename: "other.png"),
            ],
          ),
          _answer(id: "a2"),
          _user(id: "u3", parts: [_file(filename: null)]),
        ],
      );

      expect(list.entries.map((entry) => entry.text), ["Fix the build", "screen.png", null]);
      expect(list.entries.map((entry) => entry.fullText), [
        "\n  Fix the build  \nthen deploy\nThanks",
        "screen.png",
        null,
      ]);
    });

    test("groups a follow-up under its own day, or its opener's when undated, and an undated opener under none", () {
      final list = _list(
        messages: [
          _user(id: "u1", at: _tuesday),
          _working(id: "a1"),
          _user(id: "u2"),
          _user(id: "u3", at: _wednesday),
          _answer(id: "a3"),
          _user(id: "u4"),
          _working(id: "a4"),
          _user(id: "u5"),
        ],
      );

      expect(_shape(list: list), ["u1", "  u2<u1", "  u3<u1", "u4", "  u5<u4"]);
      expect(_days(list: list), [DateTime(2026, 9, 22), DateTime(2026, 9, 22), DateTime(2026, 9, 23), null, null]);
      expect(list.entries.map((entry) => entry.createdAt), [_tuesday, null, _wednesday, null, null]);
    });

    test("keeps undated older prompts above a timed newer one, in the transcript's order, and has times", () {
      final list = _list(
        messages: [
          _user(id: "u1"),
          _answer(id: "a1"),
          _user(id: "u2"),
          _answer(id: "a2"),
          _user(id: "u3", at: _monday),
        ],
      );

      expect(_shape(list: list), ["u1", "u2", "u3"]);
      expect(_days(list: list), [null, null, DateTime(2026, 9, 21)]);
      expect(list.hasTimes, isTrue);
    });

    test("gives the same list for the same messages", () {
      final messages = [
        _user(id: "u1", at: _monday),
        _working(id: "a1"),
        _user(id: "u2"),
        _answer(id: "a2"),
        _hiddenUser(id: "h1"),
        _user(id: "u3", at: _tuesday),
      ];
      List<String> describe() => [
        for (final entry in _list(messages: messages, userMessagesBefore: 4).entries)
          "${entry.runtimeType} ${entry.messageId} ${entry.text} ${entry.createdAt} ${entry.dayKey} ${entry.number}",
      ];

      expect(describe(), describe());
    });
  });
}

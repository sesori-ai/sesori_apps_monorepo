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
  List<SessionPromptIndexEntry>? index,
  int? olderMessagesCursor,
}) => const TranscriptPromptListBuilder().build(
  messages: messages,
  turns: const TranscriptTurnBuilder().build(messages: messages, hasOlderMessages: hasOlderMessages),
  userMessagesBefore: userMessagesBefore,
  index: index,
  olderMessagesCursor: olderMessagesCursor,
);

SessionPromptIndexEntry _indexed({
  required String id,
  required int seq,
  required int number,
  int? at,
  String? opener,
}) => opener == null
    ? SessionPromptIndexEntry.opener(messageId: id, seq: seq, number: number, createdAt: at, preview: "Preview $id")
    : SessionPromptIndexEntry.followUp(
        messageId: id,
        seq: seq,
        number: number,
        createdAt: at,
        preview: "Preview $id",
        openerMessageId: opener,
      );

/// `u1@3` for an unloaded prompt at seq 3, `u1` for a loaded one.
List<String> _sources({required TranscriptPromptList list}) => [
  for (final entry in list.entries)
    switch (entry.source) {
      TranscriptPromptLoaded() => entry.messageId,
      TranscriptPromptUnloaded(:final seq) => "${entry.messageId}@$seq",
    },
];

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

    test("keeps every number as three older pages load", () {
      final session = [
        _user(id: "u1"),
        _answer(id: "a1"),
        _user(id: "u2"),
        _working(id: "a2"),
        _user(id: "u3"),
        _automation(id: "x1"),
        _answer(id: "a3"),
        _hiddenUser(id: "h1"),
        _user(id: "u4"),
        _answer(id: "a4"),
        _user(id: "u5"),
        _answer(id: "a5"),
      ];
      // What the bridge reports for a page starting at [start].
      int userMessagesBefore({required int start}) =>
          session.take(start).where((message) => message.info is MessageUser).length;

      var start = session.length - 3;
      var numbers = {
        for (final entry in _list(
          messages: session.sublist(start),
          hasOlderMessages: true,
          userMessagesBefore: userMessagesBefore(start: start),
        ).entries)
          entry.messageId: entry.number,
      };
      for (var page = 0; page < 3; page++) {
        start -= 3;
        final loaded = {
          for (final entry in _list(
            messages: session.sublist(start),
            hasOlderMessages: start > 0,
            userMessagesBefore: userMessagesBefore(start: start),
          ).entries)
            entry.messageId: entry.number,
        };
        for (final MapEntry(:key, :value) in numbers.entries) {
          expect(loaded[key], value, reason: "$key after page ${page + 1}");
        }
        numbers = loaded;
      }

      expect(start, 0);
      expect(numbers, {"u1": 1, "u2": 2, "u3": 3, "u4": 5, "u5": 6});
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
      expect(list.entries.map((entry) => entry.searchText), [
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

  group("TranscriptPromptListBuilder with a prompt index", () {
    test("lists unloaded prompts from the index, and the index decides every prompt's kind, number and time", () {
      // The loaded fold reads u3 as an opener, as it cannot see the turn
      // that started before the loaded range.
      final list = _list(
        hasOlderMessages: true,
        userMessagesBefore: 2,
        olderMessagesCursor: 30,
        messages: [
          _user(id: "u3"),
          _answer(id: "a3"),
          _user(id: "u4"),
        ],
        index: [
          _indexed(id: "u1", seq: 10, number: 1, at: _monday),
          _indexed(id: "u2", seq: 20, number: 2, opener: "u1"),
          _indexed(id: "u3", seq: 30, number: 3, at: _tuesday, opener: "u1"),
          _indexed(id: "u4", seq: 40, number: 4),
        ],
      );

      expect(list.isIndexed, isTrue);
      expect(_shape(list: list), ["u1", "  u2<u1", "  u3<u1", "u4"]);
      expect(_sources(list: list), ["u1@10", "u2@20", "u3", "u4"]);
      expect(list.entries.map((entry) => entry.number), [1, 2, 3, 4]);
      expect(list.entries.map((entry) => entry.createdAt), [_monday, null, _tuesday, null]);
      // An undated follow-up groups under its opener's day.
      expect(_days(list: list), [DateTime(2026, 9, 21), DateTime(2026, 9, 21), DateTime(2026, 9, 22), null]);
      expect(list.entries.map((entry) => entry.text), ["Preview u1", "Preview u2", "Prompt u3", "Prompt u4"]);
      expect(list.entries.map((entry) => entry.searchText), ["Preview u1", "Preview u2", "Prompt u3", "Prompt u4"]);
    });

    test("lists loaded prompts the index lacks after it, as the loaded range reads them", () {
      final list = _list(
        userMessagesBefore: 1,
        olderMessagesCursor: 20,
        messages: [
          _user(id: "u2"),
          _working(id: "a2"),
          _user(id: "u3"),
          _answer(id: "a3"),
          _user(id: "u4"),
        ],
        index: [
          _indexed(id: "u1", seq: 10, number: 1),
          _indexed(id: "u2", seq: 20, number: 2),
        ],
      );

      expect(_shape(list: list), ["u1", "u2", "  u3<u2", "u4"]);
      expect(_sources(list: list), ["u1@10", "u2", "u3", "u4"]);
      expect(list.entries.map((entry) => entry.number), [1, 2, 3, 4]);
    });

    test("drops an indexed prompt inside the loaded range that the transcript does not show", () {
      final list = _list(
        olderMessagesCursor: 20,
        messages: [_user(id: "u2")],
        index: [
          _indexed(id: "u1", seq: 10, number: 1),
          _indexed(id: "u2", seq: 20, number: 2),
          _indexed(id: "gone", seq: 25, number: 3),
        ],
      );

      expect(_sources(list: list), ["u1@10", "u2"]);
    });
  });
}

import "package:sesori_bridge/src/repositories/mappers/prompt_index_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

SequencedMessage _user({required int seq, required String text}) =>
    _invokedUser(seq: seq, text: text, invocation: null);

SequencedMessage _invokedUser({required int seq, required String text, required CommandInvocation? invocation}) => (
  seq: seq,
  message: MessageWithParts(
    info: Message.user(invocation: invocation, id: "u$seq", sessionID: "s", agent: null, time: null, promptId: null),
    parts: [MessagePart.text(id: "t$seq", sessionID: "s", messageID: "u$seq", text: text)],
  ),
);

SequencedMessage _runningTool({required int seq}) => (
  seq: seq,
  message: MessageWithParts(
    info: Message.assistant(
      id: "a$seq",
      sessionID: "s",
      agent: null,
      modelID: null,
      providerID: null,
      sender: MessageSender.agent,
      time: null,
    ),
    parts: [
      MessagePart.tool(
        id: "tool$seq",
        sessionID: "s",
        messageID: "a$seq",
        tool: "bash",
        state: const ToolState(
          status: ToolStatus.running,
          title: null,
          shellCommand: null,
          output: null,
          error: null,
        ),
      ),
    ],
  ),
);

String? _preview({required String text}) =>
    const PromptIndexMapper().indexOf(messages: [_user(seq: 1, text: text)]).single.preview;

void main() {
  group("PromptIndexMapper.indexOf", () {
    test("carries the invocation of openers and follow-ups", () {
      const review = CommandInvocation(name: "review", source: CommandSource.skill, arguments: null);
      final entries = const PromptIndexMapper().indexOf(
        messages: [
          _invokedUser(seq: 1, text: "Go", invocation: review),
          _runningTool(seq: 2),
          _invokedUser(seq: 3, text: "Again", invocation: review),
          _user(seq: 4, text: "Plain"),
        ],
      );

      expect([for (final entry in entries) entry.invocation], [review, review, null]);
    });

    test("lists a prompt in the leading segment as an opener", () {
      final entries = const PromptIndexMapper().indexOf(
        messages: [
          _runningTool(seq: 1),
          _user(seq: 2, text: "Go on"),
          _user(seq: 3, text: "Faster"),
        ],
      );

      expect(entries, const [
        SessionPromptIndexEntry.opener(
          invocation: null,
          messageId: "u2",
          seq: 2,
          number: 1,
          createdAt: null,
          preview: "Go on",
        ),
        SessionPromptIndexEntry.opener(
          invocation: null,
          messageId: "u3",
          seq: 3,
          number: 2,
          createdAt: null,
          preview: "Faster",
        ),
      ]);
    });

    test("trims leading whitespace and keeps a short prompt whole", () {
      expect(_preview(text: "\n  Fix it\nthen test"), "Fix it\nthen test");
    });

    test("has no preview for a prompt of only whitespace", () {
      expect(_preview(text: " \n "), isNull);
    });

    test("cuts a long prompt to the preview length", () {
      expect(_preview(text: "x" * 400), "x" * promptIndexPreviewLength);
    });

    test("never splits a surrogate pair at the cut", () {
      final text = "${"x" * (promptIndexPreviewLength - 1)}😀 and more";

      expect(_preview(text: text), "x" * (promptIndexPreviewLength - 1));
    });
  });
}

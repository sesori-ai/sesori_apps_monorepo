import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

MessageWithParts _prompt({required String id}) => MessageWithParts(
  info: Message.user(invocation: null, handoff: null, id: id, sessionID: "s", agent: null, time: null, promptId: null),
  parts: [MessagePart.text(id: "$id-text", sessionID: "s", messageID: id, text: "Fix the build")],
);

/// A user message the transcript hides: no text and no known file.
MessageWithParts _hiddenUser({required String id}) => MessageWithParts(
  info: Message.user(invocation: null, handoff: null, id: id, sessionID: "s", agent: null, time: null, promptId: null),
  parts: const [],
);

MessageWithParts _agent({required String id, required List<MessagePart> parts}) => MessageWithParts(
  info: Message.assistant(
    id: id,
    sessionID: "s",
    agent: null,
    modelID: null,
    providerID: null,
    sender: MessageSender.agent,
    time: null,
  ),
  parts: parts,
);

MessagePart _text() => const MessagePart.text(id: "text", sessionID: "s", messageID: "m", text: "Done.");
MessagePart _tool({required ToolStatus status}) => MessagePart.tool(
  id: "tool",
  sessionID: "s",
  messageID: "m",
  tool: "read",
  state: ToolState(status: status, title: null, shellCommand: null, output: null, error: null),
);

/// `prompt:u1(u1,a1)` or `leading(a1)` per segment, oldest first.
List<String> _shape({required List<MessageWithParts> messages, required Set<String> turnEndMessageIds}) => [
  for (final segment in splitPromptTurns(messages: messages, turnEndMessageIds: turnEndMessageIds))
    "${switch (segment) {
      PromptSegment(:final opener) => "prompt:${opener.info.id}",
      LeadingPromptSegment() => "leading",
    }}(${segment.messages.map((message) => message.info.id).join(",")})",
];

void main() {
  group("splitPromptTurns", () {
    test("returns no segments for no messages", () {
      expect(splitPromptTurns(messages: const [], turnEndMessageIds: const {}), isEmpty);
    });

    test("opens a turn at each prompt after an answer", () {
      expect(
        _shape(
          messages: [
            _prompt(id: "u1"),
            _agent(id: "a1", parts: [_text()]),
            _prompt(id: "u2"),
            _agent(id: "a2", parts: [_text()]),
          ],
          turnEndMessageIds: const {},
        ),
        ["prompt:u1(u1,a1)", "prompt:u2(u2,a2)"],
      );
    });

    test("keeps a prompt sent while the turn waits or runs a step as a follow-up", () {
      expect(
        _shape(
          messages: [
            _prompt(id: "u1"),
            _prompt(id: "u2"),
            _agent(
              id: "a1",
              parts: [_tool(status: ToolStatus.running)],
            ),
            _prompt(id: "u3"),
          ],
          turnEndMessageIds: const {},
        ),
        ["prompt:u1(u1,u2,a1,u3)"],
      );
    });

    test("opens a turn after a step that failed", () {
      expect(
        _shape(
          messages: [
            _prompt(id: "u1"),
            _agent(
              id: "a1",
              parts: [_tool(status: ToolStatus.error)],
            ),
            _prompt(id: "u2"),
          ],
          turnEndMessageIds: const {},
        ),
        ["prompt:u1(u1,a1)", "prompt:u2(u2)"],
      );
    });

    test("keeps messages before the first prompt in one leading segment", () {
      expect(
        _shape(
          messages: [
            _agent(
              id: "a0",
              parts: [_tool(status: ToolStatus.running)],
            ),
            _prompt(id: "u1"),
            _agent(id: "a1", parts: [_text()]),
            _prompt(id: "u2"),
          ],
          turnEndMessageIds: const {},
        ),
        ["leading(a0,u1,a1)", "prompt:u2(u2)"],
      );
    });

    test("leaves hidden user messages out", () {
      expect(
        _shape(
          messages: [
            _hiddenUser(id: "h1"),
            _prompt(id: "u1"),
            _agent(id: "a1", parts: [_text()]),
            _hiddenUser(id: "h2"),
          ],
          turnEndMessageIds: const {},
        ),
        ["prompt:u1(u1,a1)"],
      );
    });

    test("ends a turn after a turn-end message, so the next prompt opens one", () {
      final messages = [
        _prompt(id: "u1"),
        _prompt(id: "u2"),
        _agent(id: "a2", parts: [_text()]),
      ];
      expect(_shape(messages: messages, turnEndMessageIds: const {}), ["prompt:u1(u1,u2,a2)"]);
      expect(_shape(messages: messages, turnEndMessageIds: const {"u1"}), ["prompt:u1(u1)", "prompt:u2(u2,a2)"]);
    });

    test("ends a turn after a turn-end message mid-step", () {
      expect(
        _shape(
          messages: [
            _prompt(id: "u1"),
            _agent(
              id: "a1",
              parts: [_tool(status: ToolStatus.running)],
            ),
            _prompt(id: "u2"),
          ],
          turnEndMessageIds: const {"a1"},
        ),
        ["prompt:u1(u1,a1)", "prompt:u2(u2)"],
      );
    });
  });

  group("SessionMessagePresentation", () {
    test("names a prompt by its text, else its first attachment's name", () {
      const file = MessagePart.file(
        id: "file",
        sessionID: "s",
        messageID: "u1",
        attachment: MessageAttachment.metadata(mime: "image/png", filename: " shot.png "),
      );
      const attachmentOnly = MessageWithParts(
        info: Message.user(
          invocation: null,
          handoff: null,
          id: "u1",
          sessionID: "s",
          agent: null,
          time: null,
          promptId: null,
        ),
        parts: [file],
      );

      expect(_prompt(id: "u1").promptText, "Fix the build");
      expect(attachmentOnly.promptText, "shot.png");
      expect(attachmentOnly.hasRenderableUserContent, isTrue);
      expect(_hiddenUser(id: "u1").promptText, isNull);
      expect(_hiddenUser(id: "u1").hasRenderableUserContent, isFalse);
    });
  });
}

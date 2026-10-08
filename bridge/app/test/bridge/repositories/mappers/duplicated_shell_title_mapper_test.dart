import "package:sesori_bridge/src/repositories/mappers/duplicated_shell_title_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("withoutDuplicatedShellTitles", () {
    test("drops a shell tool's title when it repeats the command", () {
      final message = _message(
        parts: [_tool(title: "git status", shellCommand: "git status")],
      );

      final state = (message.withoutDuplicatedShellTitles().parts.single as MessagePartTool).state as ToolStateFull;

      expect(state.title, isNull);
      expect(state.shellCommand, "git status");
      expect(state.output, "clean");
    });

    test("keeps a shell tool's title when it differs from the command", () {
      final part = _tool(title: "Check the tree", shellCommand: "git status");

      expect(_message(parts: [part]).withoutDuplicatedShellTitles().parts.single, part);
    });

    test("keeps a non-shell tool's title and every other part", () {
      final parts = [
        _tool(title: "lib/main.dart", shellCommand: null),
        const MessagePart.text(id: "p2", sessionID: "ses_a", messageID: "m1", text: "git status"),
      ];

      expect(_message(parts: parts).withoutDuplicatedShellTitles().parts, parts);
    });
  });
}

MessageWithParts _message({required List<MessagePart> parts}) => MessageWithParts(
  info: const Message.user(
    promptId: null,
    id: "m1",
    sessionID: "ses_a",
    agent: null,
    time: MessageTime(created: 1, completed: null),
  ),
  parts: parts,
);

MessagePart _tool({required String title, required String? shellCommand}) => MessagePart.tool(
  id: "p1",
  sessionID: "ses_a",
  messageID: "m1",
  tool: "bash",
  state: ToolState(
    status: ToolStatus.completed,
    title: title,
    shellCommand: shellCommand,
    output: "clean",
    error: null,
  ),
);

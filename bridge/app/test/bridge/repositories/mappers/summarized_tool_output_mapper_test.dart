import "package:sesori_bridge/src/repositories/mappers/summarized_tool_output_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("withSummarizedToolOutput", () {
    const attachments = [MessageAttachment.metadata(mime: "image/png", filename: "shot.png")];
    const finished = {ToolStatus.completed, ToolStatus.error, ToolStatus.cancelled};

    for (final status in ToolStatus.values) {
      final summarized = finished.contains(status);
      test("${summarized ? "summarizes" : "keeps"} a ${status.name} tool with output or error", () {
        for (final (output, error) in const [("out", null), (null, "err"), ("out", "err")]) {
          final part = _tool(
            state: ToolState(
              status: status,
              title: "List files",
              shellCommand: "ls",
              output: output,
              error: error,
              attachments: attachments,
            ),
          );

          final projected = _message(parts: [part]).withSummarizedToolOutput().parts.single;

          expect(
            projected,
            summarized
                ? _tool(
                    state: ToolState.summary(
                      status: status,
                      title: "List files",
                      shellCommand: "ls",
                      attachments: attachments,
                    ),
                  )
                : part,
          );
        }
      });
    }

    test("keeps a finished tool with neither output nor error", () {
      final part = _tool(
        state: const ToolState(
          status: ToolStatus.completed,
          title: "a.dart",
          shellCommand: null,
          output: null,
          error: null,
        ),
      );

      expect(_message(parts: [part]).withSummarizedToolOutput().parts.single, part);
    });

    test("keeps subtasks and other parts", () {
      final parts = [
        const MessagePart.subtask(
          id: "p1",
          sessionID: "ses_a",
          messageID: "m1",
          taskState: ToolState(
            status: ToolStatus.completed,
            title: null,
            shellCommand: null,
            output: "done",
            error: null,
          ),
          childSessionID: null,
        ),
        const MessagePart.text(id: "p2", sessionID: "ses_a", messageID: "m1", text: "done"),
      ];

      expect(_message(parts: parts).withSummarizedToolOutput().parts, parts);
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

MessagePart _tool({required ToolState state}) =>
    MessagePart.tool(id: "p1", sessionID: "ses_a", messageID: "m1", tool: "bash", state: state);

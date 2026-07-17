import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const mapper = OpenCodeCommandMapper();

  test("maps command fields without making correlation decisions", () {
    final message = mapper.mapCommand(
      id: "msg_sesori_0123456789abcdef0123456789abcdef",
      sessionId: "session",
      name: "review",
      arguments: "recent changes",
      origin: PluginCommandOrigin.manual,
      invocationId: "opaque-invocation",
      time: const PluginMessageTime(created: 10, completed: null),
    );

    expect(
      message,
      isA<PluginMessageCommand>()
          .having((command) => command.id, "id", "msg_sesori_0123456789abcdef0123456789abcdef")
          .having((command) => command.name, "name", "review")
          .having((command) => command.arguments, "arguments", "recent changes")
          .having((command) => command.invocationId, "invocationId", "opaque-invocation"),
    );
  });

  test("reparents result updates without changing backend part identity", () {
    const part = PluginMessagePart(
      id: "result-part",
      sessionID: "session",
      messageID: "assistant-result",
      type: PluginMessagePartType.text,
      text: "result",
      tool: null,
      state: null,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
    );

    final updated =
        mapper.reparentEvent(
              event: const BridgeSseMessagePartUpdated(part: part),
              commandMessageId: "command-trigger",
            )
            as BridgeSseMessagePartUpdated;
    final delta =
        mapper.reparentEvent(
              event: const BridgeSseMessagePartDelta(
                sessionID: "session",
                messageID: "assistant-result",
                partID: "result-part",
                field: "text",
                delta: "more",
              ),
              commandMessageId: "command-trigger",
            )
            as BridgeSseMessagePartDelta;

    expect(updated.part.id, "result-part");
    expect(updated.part.messageID, "command-trigger");
    expect(delta.messageID, "command-trigger");
    expect(delta.partID, "result-part");
  });

  test("maps an error field to visible command result text", () {
    final part = mapper.mapErrorResult(
      error: const PluginMessageError(
        id: "assistant-error",
        sessionID: "session",
        agent: "build",
        modelID: "gpt",
        providerID: "openai",
        errorName: "UnknownError",
        errorMessage: "Command failed",
        time: PluginMessageTime(created: 20, completed: 21),
      ),
      commandMessageId: "command-trigger",
    );

    expect(part.id, "assistant-error");
    expect(part.messageID, "command-trigger");
    expect(part.type, PluginMessagePartType.text);
    expect(part.text, "Command failed");
    expect(part.type.isVisible, isTrue);
  });
}

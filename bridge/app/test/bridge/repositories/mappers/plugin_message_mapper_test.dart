import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_message_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PluginMessageMapper.toSharedMessage()", () {
    test("preserves time on a user message", () {
      const message = PluginMessage.user(
        id: "m1",
        sessionID: "s1",
        agent: null,
        time: PluginMessageTime(created: 1718400000000, completed: null),
      );

      expect(
        message.toSharedMessage(sessionId: "stable-session"),
        equals(
          const Message.user(
            id: "m1",
            sessionID: "stable-session",
            agent: null,
            time: MessageTime(created: 1718400000000, completed: null),
          ),
        ),
      );
    });

    test("preserves created + completed on an assistant message", () {
      const message = PluginMessage.assistant(
        id: "m2",
        sessionID: "s1",
        agent: "build",
        modelID: "gpt",
        providerID: "openai",
        time: PluginMessageTime(created: 1718400000000, completed: 1718400005000),
      );

      expect(
        message.toSharedMessage(sessionId: "stable-session"),
        equals(
          const Message.assistant(
            id: "m2",
            sessionID: "stable-session",
            agent: "build",
            modelID: "gpt",
            providerID: "openai",
            time: MessageTime(created: 1718400000000, completed: 1718400005000),
          ),
        ),
      );
    });

    test("preserves time on an error message", () {
      const message = PluginMessage.error(
        id: "m3",
        sessionID: "s1",
        agent: null,
        modelID: "gpt",
        providerID: "openai",
        errorName: "ProviderError",
        errorMessage: "boom",
        time: PluginMessageTime(created: 1718400000000, completed: 1718400001000),
      );

      expect(
        message.toSharedMessage(sessionId: "stable-session"),
        equals(
          const Message.error(
            id: "m3",
            sessionID: "stable-session",
            agent: null,
            modelID: "gpt",
            providerID: "openai",
            errorName: "ProviderError",
            errorMessage: "boom",
            time: MessageTime(created: 1718400000000, completed: 1718400001000),
          ),
        ),
      );
    });

    test("maps a null time to null", () {
      const message = PluginMessage.user(
        id: "m4",
        sessionID: "s1",
        agent: null,
        time: null,
      );

      expect(message.toSharedMessage(sessionId: "stable-session").time, isNull);
    });

    test("maps command metadata, fallback text, and result text onto one user message", () {
      const message = PluginMessageWithParts(
        info: PluginMessage.command(
          id: "command-1",
          sessionID: "backend-session",
          name: "review",
          arguments: "carefully",
          origin: PluginCommandOrigin.manual,
          invocationId: null,
          time: PluginMessageTime(created: 10, completed: 20),
        ),
        parts: [
          PluginMessagePart(
            id: "result-1",
            sessionID: "backend-session",
            messageID: "command-1",
            type: PluginMessagePartType.text,
            text: "Review complete",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ],
      );

      final mapped = message.toSharedMessageWithParts(sessionId: "stable-session");

      expect(mapped.info, isA<MessageUser>());
      final command = (mapped.info as MessageUser).command!;
      expect(command.name, "review");
      expect(command.arguments, "carefully");
      expect(command.origin, CommandOrigin.manual);
      expect(command.displayPartID, mapped.parts.last.id);
      expect(mapped.parts.first.id, "command-backend:command-1:fallback");
      expect(mapped.parts.map((part) => part.text), ["/review carefully", "Review complete"]);
      expect(mapped.parts.every((part) => part.messageID == mapped.info.id), isTrue);
    });
  });
}

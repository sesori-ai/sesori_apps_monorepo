import "package:sesori_bridge/src/repositories/mappers/plugin_message_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PluginMessageMapper.toSharedMessage()", () {
    test("preserves time on a user message", () {
      const message = PluginMessage.user(
        promptId: null,
        id: "m1",
        sessionID: "s1",
        agent: null,
        time: PluginMessageTime(created: 1718400000000, completed: null),
      );

      expect(
        message.toSharedMessage(sessionId: "stable-session"),
        equals(
          const Message.user(
            promptId: null,
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
        variant: "high",
        sender: PluginMessageSender.agent,
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
            sender: MessageSender.agent,
            time: MessageTime(created: 1718400000000, completed: 1718400005000),
          ),
        ),
      );

      expect(
        [const PluginMessageWithParts(info: message, parts: [])].latestPromptDefaults(),
        const SessionPromptDefaults(
          agent: "build",
          model: AgentModel(providerID: "openai", modelID: "gpt", variant: "high"),
        ),
      );
    });

    test("maps system attribution without using it as prompt defaults", () {
      const message = PluginMessage.assistant(
        id: "m-system",
        sessionID: "s1",
        agent: null,
        modelID: null,
        providerID: null,
        variant: null,
        sender: PluginMessageSender.system,
        time: PluginMessageTime(created: 1718400000000, completed: null),
      );

      final shared = message.toSharedMessage(sessionId: "stable-session");

      expect(shared, isA<MessageAssistant>());
      expect((shared as MessageAssistant).sender, MessageSender.system);
      expect([const PluginMessageWithParts(info: message, parts: [])].latestPromptDefaults(), isNull);
    });

    test("preserves time on an error message", () {
      const message = PluginMessage.error(
        id: "m3",
        sessionID: "s1",
        agent: null,
        modelID: "gpt",
        providerID: "openai",
        variant: null,
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
        promptId: null,
        id: "m4",
        sessionID: "s1",
        agent: null,
        time: null,
      );

      expect(message.toSharedMessage(sessionId: "stable-session").time, isNull);
    });

    test("latestPromptDefaults uses the newest assistant or error attribution", () {
      const messages = [
        PluginMessageWithParts(
          info: PluginMessage.assistant(
            id: "m1",
            sessionID: "s1",
            agent: "build",
            modelID: "gpt",
            providerID: "openai",
            variant: "low",
            sender: PluginMessageSender.agent,
            time: null,
          ),
          parts: [],
        ),
        PluginMessageWithParts(
          info: PluginMessage.user(
            promptId: null,
            id: "m2",
            sessionID: "s1",
            agent: null,
            time: null,
          ),
          parts: [],
        ),
        PluginMessageWithParts(
          info: PluginMessage.error(
            id: "m3",
            sessionID: "s1",
            agent: "review",
            modelID: "gpt",
            providerID: null,
            variant: "high",
            errorName: "ProviderError",
            errorMessage: "boom",
            time: null,
          ),
          parts: [],
        ),
      ];

      expect(
        messages.latestPromptDefaults(),
        const SessionPromptDefaults(agent: "review", model: null),
      );
    });

    test("latestPromptDefaults skips renderer-only assistant messages", () {
      const messages = [
        PluginMessageWithParts(
          info: PluginMessage.assistant(
            id: "m1",
            sessionID: "s1",
            agent: "pi",
            modelID: "claude-sonnet-4-5",
            providerID: "anthropic",
            variant: "high",
            sender: PluginMessageSender.agent,
            time: null,
          ),
          parts: [],
        ),
        PluginMessageWithParts(
          info: PluginMessage.assistant(
            id: "m2",
            sessionID: "s1",
            agent: "pi",
            modelID: null,
            providerID: null,
            variant: null,
            sender: PluginMessageSender.agent,
            time: null,
          ),
          parts: [],
        ),
      ];

      expect(
        messages.latestPromptDefaults(),
        const SessionPromptDefaults(
          agent: "pi",
          model: AgentModel(providerID: "anthropic", modelID: "claude-sonnet-4-5", variant: "high"),
        ),
      );
    });

    test("latestPromptDefaults ignores transcripts without assistant or error messages", () {
      const messages = [
        PluginMessageWithParts(
          info: PluginMessage.user(
            promptId: null,
            id: "m1",
            sessionID: "s1",
            agent: null,
            time: null,
          ),
          parts: [],
        ),
      ];

      expect(messages.latestPromptDefaults(), isNull);
    });
  });
}

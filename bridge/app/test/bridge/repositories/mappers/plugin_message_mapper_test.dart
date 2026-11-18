import "package:sesori_bridge/src/repositories/mappers/plugin_message_mapper.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show buildSessionNotice;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PluginMessageMapper.toSharedMessage()", () {
    test("preserves time on a user message", () {
      const message = PluginMessage.user(
        promptId: null,
        invocation: null,
        id: "m1",
        sessionID: "s1",
        agent: null,
        time: PluginMessageTime(created: 1718400000000, completed: null),
      );

      expect(
        message.toSharedMessage(sessionId: "stable-session"),
        equals(
          const Message.user(
            invocation: null,
            handoff: null,
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
        kind: PluginErrorKind.failure,
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

    test("carries each error kind", () {
      for (final (kind, expected) in const [
        (PluginErrorKind.failure, MessageErrorKind.failure),
        (PluginErrorKind.stopped, MessageErrorKind.stopped),
      ]) {
        final message = PluginMessage.error(
          id: "m3",
          sessionID: "s1",
          agent: null,
          modelID: null,
          providerID: null,
          variant: null,
          kind: kind,
          errorName: "Fixture",
          errorMessage: "Fixture text",
          time: null,
        );

        expect((message.toSharedMessage(sessionId: "s1") as MessageError).kind, expected);
      }
    });

    test("maps a null time to null", () {
      const message = PluginMessage.user(
        promptId: null,
        invocation: null,
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
            invocation: null,
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
            kind: PluginErrorKind.failure,
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
            invocation: null,
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

  group("PluginMessageWithPartsMapper.toSharedMessageWithParts()", () {
    final notice = buildSessionNotice(summary: "Fixture summary", guidance: "Fixture guidance");
    PluginMessageWithParts userTurn({required List<String> texts}) => PluginMessageWithParts(
      info: const PluginMessage.user(
        promptId: null,
        invocation: null,
        id: "m1",
        sessionID: "s1",
        agent: "build",
        time: PluginMessageTime(created: 1234, completed: null),
      ),
      parts: [
        for (final (index, text) in texts.indexed)
          PluginMessagePart.text(id: "p$index", sessionID: "s1", messageID: "m1", text: text),
      ],
    );

    test("replays a notice as a Sesori row showing only its summary", () {
      expect(
        userTurn(texts: [notice]).toSharedMessageWithParts(sessionId: "stable-session"),
        const MessageWithParts(
          info: Message.assistant(
            id: "m1",
            sessionID: "stable-session",
            agent: null,
            modelID: null,
            providerID: null,
            sender: MessageSender.sesori,
            time: MessageTime(created: 1234, completed: null),
          ),
          parts: [MessagePart.text(id: "p0", sessionID: "stable-session", messageID: "m1", text: "Fixture summary")],
        ),
      );
    });

    test("keeps a user turn that only quotes a notice", () {
      final shared = userTurn(texts: [notice, "Why did this arrive?"]).toSharedMessageWithParts(sessionId: "s1");

      expect(shared.info, isA<MessageUser>());
    });
  });
}

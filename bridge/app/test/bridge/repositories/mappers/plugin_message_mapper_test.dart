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
        message.toSharedMessage(),
        equals(
          const Message.user(
            id: "m1",
            sessionID: "s1",
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
        message.toSharedMessage(),
        equals(
          const Message.assistant(
            id: "m2",
            sessionID: "s1",
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
        message.toSharedMessage(),
        equals(
          const Message.error(
            id: "m3",
            sessionID: "s1",
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

      expect(message.toSharedMessage().time, isNull);
    });
  });
}

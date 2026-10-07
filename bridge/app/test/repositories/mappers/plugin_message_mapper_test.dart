import "package:sesori_bridge/src/repositories/mappers/plugin_message_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("PluginMessagePartsMapper.toSharedMessageWithParts", () {
    test("drops unknown parts instead of throwing", () {
      // Arrange: a backend history message that carries a content block the
      // plugin could not model (e.g. Claude's server_tool_use).
      const messages = [
        PluginMessageWithParts(
          info: PluginMessage.assistant(
            id: "m1",
            sessionID: "backend-session",
            agent: null,
            modelID: null,
            providerID: null,
            variant: null,
            sender: PluginMessageSender.agent,
            time: null,
          ),
          parts: [
            PluginMessagePart.text(id: "p1", sessionID: "backend-session", messageID: "m1", text: "before"),
            PluginMessagePart.unknown(id: "p2", sessionID: "backend-session", messageID: "m1"),
            PluginMessagePart.text(id: "p3", sessionID: "backend-session", messageID: "m1", text: "after"),
          ],
        ),
      ];

      // Act
      final shared = messages.toSharedMessageWithParts(sessionId: "s1");

      // Assert
      expect(shared, hasLength(1));
      expect(shared.single.parts.map((part) => part.id), ["p1", "p3"]);
      expect(shared.single.parts.every((part) => part.sessionID == "s1"), isTrue);
    });
  });
}

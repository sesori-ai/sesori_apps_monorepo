import "package:sesori_bridge/src/bridge/plugin_to_shared_mapping.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PluginMessagePartTypeMapping.toShared()", () {
    test("maps patch to MessagePartType.patch", () {
      expect(PluginMessagePartType.patch.toShared(), equals(MessagePartType.patch));
    });

    test("maps agent to MessagePartType.agent", () {
      expect(PluginMessagePartType.agent.toShared(), equals(MessagePartType.agent));
    });

    test("maps retry to MessagePartType.retry", () {
      expect(PluginMessagePartType.retry.toShared(), equals(MessagePartType.retry));
    });

    test("maps compaction to MessagePartType.compaction", () {
      expect(PluginMessagePartType.compaction.toShared(), equals(MessagePartType.compaction));
    });

    test("throws StateError for unknown", () {
      expect(() => PluginMessagePartType.unknown.toShared(), throwsStateError);
    });
  });

  group("PluginMessagePartMapping.toShared()", () {
    test("passes through agentName", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.agent,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: "my-agent",
        attempt: null,
        retryError: null,
      );

      final shared = part.toShared();

      expect(shared.agentName, equals("my-agent"));
    });

    test("passes through attempt", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.retry,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: 3,
        retryError: null,
      );

      final shared = part.toShared();

      expect(shared.attempt, equals(3));
    });

    test("passes through retryError", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.retry,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: 1,
        retryError: "connection timeout",
      );

      final shared = part.toShared();

      expect(shared.retryError, equals("connection timeout"));
    });

    test("passes through null values for new fields", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.text,
        text: "hello",
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
      );

      final shared = part.toShared();

      expect(shared.agentName, isNull);
      expect(shared.attempt, isNull);
      expect(shared.retryError, isNull);
    });
  });
}

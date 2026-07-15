import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:test/test.dart";

void main() {
  group("CursorEventMapper", () {
    final mapper = CursorEventMapper(launchDirectory: "/repo", pluginId: CursorPlugin.pluginId);

    test("cursor/update_todos maps to a todo update", () {
      final events = mapper.map(
        const AcpNotification(
          method: "cursor/update_todos",
          params: {"sessionId": "s1", "todos": <Object?>[]},
        ),
      );
      expect(events.single, isA<BridgeSseTodoUpdated>());
      expect((events.single as BridgeSseTodoUpdated).sessionID, "s1");
    });

    test("other cursor extensions are dropped", () {
      expect(
        mapper.map(const AcpNotification(method: "cursor/task", params: {})),
        isEmpty,
      );
    });

    test("standard session/update still works via the base mapper", () {
      mapper.beginTurn("s1");
      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "s1",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              "content": {"type": "text", "text": "hi"},
            },
          },
        ),
      );
      expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "hi");
    });

    test("an account/plan gate notice becomes an error message, not assistant text", () {
      mapper.beginTurn("sg");
      final events = mapper.map(
        const AcpNotification(
          method: "session/update",
          params: {
            "sessionId": "sg",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              // Exact wire capture from cursor-agent when a gated model is used.
              "content": {"type": "text", "text": "\n\nCheck your settings to continue"},
            },
          },
        ),
      );
      final message = shared.Message.fromJson(
        events.whereType<BridgeSseMessageUpdated>().single.info,
      );
      expect(message, isA<shared.MessageError>());
      expect(
        (message as shared.MessageError).errorMessage,
        "Check your settings to continue",
      );
      expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
    });

    test("gate matching tolerates case and surrounding decoration", () {
      expect(mapper.classifyHaltNotice("  CHECK YOUR SETTINGS TO CONTINUE.  "), isNotNull);
      expect(mapper.classifyHaltNotice("⚠️ Check your settings to continue"), isNotNull);
    });

    test("ordinary prose that merely contains the phrase is not a gate", () {
      expect(
        mapper.classifyHaltNotice(
          "Sure — check your settings to continue setting up the project, then rerun.",
        ),
        isNull,
      );
    });
  });
}

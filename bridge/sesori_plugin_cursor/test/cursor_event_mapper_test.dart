import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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
  });
}

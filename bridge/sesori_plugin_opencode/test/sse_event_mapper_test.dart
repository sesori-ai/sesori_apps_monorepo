import "package:opencode_plugin/src/models/session.dart";
import "package:opencode_plugin/src/models/sse_event_data.dart";
import "package:opencode_plugin/src/sse_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("SseEventMapper", () {
    final mapper = SseEventMapper();

    test("maps session.created using provided canonical projectID", () {
      const session = Session(
        id: "session-1",
        projectID: "/repo",
        directory: "/repo/packages/foo",
      );

      final result = mapper.map(const SseEventData.sessionCreated(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionCreated;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
    });

    test("maps session.updated using provided canonical projectID", () {
      const session = Session(
        id: "session-2",
        projectID: "/repo",
        directory: "/repo/packages/foo",
      );

      final result = mapper.map(const SseEventData.sessionUpdated(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionUpdated;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
    });

    test("maps session.deleted using provided canonical projectID", () {
      const session = Session(
        id: "session-3",
        projectID: "/repo",
        directory: "/repo/packages/foo",
      );

      final result = mapper.map(const SseEventData.sessionDeleted(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionDeleted;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
    });
  });
}

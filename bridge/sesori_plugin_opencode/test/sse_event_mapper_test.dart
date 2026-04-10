import "package:opencode_plugin/src/models/session.dart";
import "package:opencode_plugin/src/models/sse_event_data.dart";
import "package:opencode_plugin/src/sse_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("SseEventMapper", () {
    test("maps subdirectory session.created to root projectID", () {
      const session = Session(
        id: "session-1",
        projectID: "internal-opencode-id",
        directory: "/repo/packages/foo",
      );

      final result = SseEventMapper().map(
        const SseEventData.sessionCreated(info: session),
        resolveProjectID: (directory) => directory.startsWith("/repo") ? "/repo" : null,
      );

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionCreated;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
      expect(event.info["projectID"], isNot(equals("internal-opencode-id")));
    });

    test("maps subdirectory session.updated to root projectID", () {
      const session = Session(
        id: "session-2",
        projectID: "internal-opencode-id",
        directory: "/repo/packages/foo",
      );

      final result = SseEventMapper().map(
        const SseEventData.sessionUpdated(info: session),
        resolveProjectID: (directory) => directory.startsWith("/repo") ? "/repo" : null,
      );

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionUpdated;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
      expect(event.info["projectID"], isNot(equals("internal-opencode-id")));
    });

    test("maps subdirectory session.deleted to root projectID", () {
      const session = Session(
        id: "session-3",
        projectID: "internal-opencode-id",
        directory: "/repo/packages/foo",
      );

      final result = SseEventMapper().map(
        const SseEventData.sessionDeleted(info: session),
        resolveProjectID: (directory) => directory.startsWith("/repo") ? "/repo" : null,
      );

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionDeleted;
      expect(event.info["projectID"], equals("/repo"));
      expect(event.info["directory"], equals("/repo/packages/foo"));
      expect(event.info["projectID"], isNot(equals("internal-opencode-id")));
    });
  });
}

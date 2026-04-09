import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "package:opencode_plugin/src/models/session.dart";
import "package:opencode_plugin/src/models/sse_event_data.dart";
import "package:opencode_plugin/src/sse_event_mapper.dart";

void main() {
  group("SseEventMapper", () {
    test("overrides projectID for session.created", () {
      const session = Session(
        id: "session-1",
        projectID: "internal-opencode-id",
        directory: "/home/user/my-project",
      );

      final result = SseEventMapper().map(SseEventData.sessionCreated(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionCreated;
      expect(event.info["projectID"], equals("/home/user/my-project"));
      expect(event.info["projectID"], isNot(equals("internal-opencode-id")));
    });

    test("overrides projectID for session.updated", () {
      const session = Session(
        id: "session-2",
        projectID: "internal-opencode-id",
        directory: "/home/user/my-project",
      );

      final result = SseEventMapper().map(SseEventData.sessionUpdated(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionUpdated;
      expect(event.info["projectID"], equals("/home/user/my-project"));
      expect(event.info["projectID"], isNot(equals("internal-opencode-id")));
    });

    test("overrides projectID for session.deleted", () {
      const session = Session(
        id: "session-3",
        projectID: "internal-opencode-id",
        directory: "/home/user/my-project",
      );

      final result = SseEventMapper().map(SseEventData.sessionDeleted(info: session));

      expect(result, isNotNull);
      final event = result! as BridgeSseSessionDeleted;
      expect(event.info["projectID"], equals("/home/user/my-project"));
      expect(event.info["projectID"], isNot(equals("internal-opencode-id")));
    });
  });
}

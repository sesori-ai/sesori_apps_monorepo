import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RelayMessage.projectView", () {
    test("round-trips a project id", () {
      const message = RelayMessage.projectView(projectId: "project-1");

      final json = message.toJson();

      expect(json, equals({"type": "project_view", "projectId": "project-1"}));
      expect(RelayMessage.fromJson(json), message);
    });

    test("round-trips a null project id", () {
      const message = RelayMessage.projectView(projectId: null);

      final json = message.toJson();

      expect(json, equals({"type": "project_view"}));
      expect(RelayMessage.fromJson(json), message);
    });

    test("does not change session-view round trips", () {
      const message = RelayMessage.sessionView(sessionId: "session-1");

      final json = message.toJson();

      expect(json, equals({"type": "session_view", "sessionId": "session-1"}));
      expect(RelayMessage.fromJson(json), message);
    });
  });
}

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("NotificationData", () {
    test("round-trips the computer id", () {
      const data = NotificationData(
        category: NotificationCategory.aiInteraction,
        eventType: NotificationEventType.questionAsked,
        sessionId: "session-1",
        projectId: "project-1",
        bridgeId: "br_workstation",
      );

      expect(data.toJson()["bridgeId"], "br_workstation");
      expect(NotificationData.fromJson(data.toJson()), data);
    });

    test("reads a push from a bridge that does not send the computer id", () {
      final data = NotificationData.fromJson({
        "category": "session_message",
        "eventType": "agent_turn_completed",
        "sessionId": "session-1",
        "projectId": "project-1",
      });

      expect(data.sessionId, "session-1");
      expect(data.bridgeId, isNull);
    });

    test("omits an absent computer id from the wire", () {
      const data = NotificationData(
        category: NotificationCategory.systemUpdate,
        eventType: NotificationEventType.installationUpdateAvailable,
        sessionId: null,
        projectId: null,
        bridgeId: null,
      );

      expect(data.toJson().containsKey("bridgeId"), isFalse);
    });
  });
}

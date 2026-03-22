import "package:sesori_bridge/src/push/notification_category.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("categorizeEvent", () {
    test("maps question.asked and permission.asked to ai_interaction", () {
      const questionEvent = SesoriSseEvent.questionAsked(
        id: "q-1",
        sessionID: "session-a",
        questions: [QuestionInfo(question: "Continue?", header: "Prompt")],
      );
      const permissionEvent = SesoriSseEvent.permissionAsked(
        requestID: "r-1",
        sessionID: "session-a",
        tool: "bash",
        description: "Run command",
      );

      expect(categorizeEvent(questionEvent), NotificationCategory.aiInteraction);
      expect(categorizeEvent(permissionEvent), NotificationCategory.aiInteraction);
    });

    test("maps message.updated to session_message", () {
      const event = SesoriSseEvent.messageUpdated(
        info: Message(role: "assistant", id: "m-1", sessionID: "session-a"),
      );

      expect(categorizeEvent(event), NotificationCategory.sessionMessage);
    });

    test("maps installation.update-available to system_update", () {
      const event = SesoriSseEvent.installationUpdateAvailable(version: "1.2.3");

      expect(categorizeEvent(event), NotificationCategory.systemUpdate);
    });

    test("returns null for unsupported events", () {
      expect(categorizeEvent(const SesoriSseEvent.serverHeartbeat()), isNull);
    });
  });

  group("buildNotificationPayload", () {
    test("includes session data and collapse key for session-scoped events", () {
      const event = SesoriSseEvent.questionAsked(
        id: "q-1",
        sessionID: "session-a",
        questions: [QuestionInfo(question: "Ship it?", header: "Prompt")],
      );

      final payload = buildNotificationPayload(event, NotificationCategory.aiInteraction);

      expect(payload, isNotNull);
      expect(payload!.title, equals("Question requires input"));
      expect(payload.body, equals("Ship it?"));
      expect(payload.collapseKey, equals("ai_interaction-session-a"));
      expect(payload.data, equals({"sessionId": "session-a"}));
    });

    test("omits session data for non-session events", () {
      const event = SesoriSseEvent.installationUpdateAvailable(version: "2.0.0");

      final payload = buildNotificationPayload(event, NotificationCategory.systemUpdate);

      expect(payload, isNotNull);
      expect(payload!.collapseKey, isNull);
      expect(payload.data, isNull);
    });

    test("returns null when category does not match event", () {
      const event = SesoriSseEvent.messageUpdated(
        info: Message(role: "assistant", id: "m-1", sessionID: "session-a"),
      );

      final payload = buildNotificationPayload(event, NotificationCategory.aiInteraction);

      expect(payload, isNull);
    });
  });
}

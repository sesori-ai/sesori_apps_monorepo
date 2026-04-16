import "package:sesori_bridge/src/push/push_notification_content_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const contentService = PushNotificationContentService();

  group("extractNotificationData", () {
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

      expect(contentService.extractNotificationData(questionEvent)?.category, NotificationCategory.aiInteraction);
      expect(contentService.extractNotificationData(permissionEvent)?.category, NotificationCategory.aiInteraction);
    });

    test("maps installation.update-available to system_update", () {
      const event = SesoriSseEvent.installationUpdateAvailable(version: "1.2.3");

      expect(contentService.extractNotificationData(event)?.category, NotificationCategory.systemUpdate);
    });

    test("returns null for unsupported events", () {
      expect(contentService.extractNotificationData(const SesoriSseEvent.serverHeartbeat()), isNull);
    });
  });

  group("buildNotificationPayload", () {
    test("includes session data and collapse key for session-scoped events", () {
      const event = SesoriSseEvent.questionAsked(
        id: "q-1",
        sessionID: "session-a",
        questions: [QuestionInfo(question: "Ship it?", header: "Prompt")],
      );

      final data = contentService.extractNotificationData(event)!;
      final sessionId = contentService.extractSessionId(event);
      final payload = contentService.buildNotificationPayload(
        category: data.category,
        eventType: data.eventType,
        title: data.title,
        body: data.body,
        collapseKey: "${data.category.id}-${sessionId ?? "global"}",
        sessionId: sessionId,
        projectId: null,
      );

      expect(payload.title, equals("Question requires input"));
      expect(payload.body, equals("Ship it?"));
      expect(payload.collapseKey, equals("ai_interaction-session-a"));
      expect(payload.data?.sessionId, equals("session-a"));
      expect(payload.data?.category, equals(NotificationCategory.aiInteraction));
      expect(payload.data?.eventType, equals(NotificationEventType.questionAsked));
    });

    test("omits session data for non-session events", () {
      const event = SesoriSseEvent.installationUpdateAvailable(version: "2.0.0");

      final data = contentService.extractNotificationData(event)!;
      final sessionId = contentService.extractSessionId(event);
      final payload = contentService.buildNotificationPayload(
        category: data.category,
        eventType: data.eventType,
        title: data.title,
        body: data.body,
        collapseKey: "${data.category.id}-${sessionId ?? "global"}",
        sessionId: sessionId,
        projectId: null,
      );

      expect(payload.collapseKey, equals("system_update-global"));
      expect(payload.data?.sessionId, isNull);
      expect(payload.data?.category, equals(NotificationCategory.systemUpdate));
      expect(
        payload.data?.eventType,
        equals(NotificationEventType.installationUpdateAvailable),
      );
    });
  });
}

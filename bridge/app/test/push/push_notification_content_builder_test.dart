import "package:sesori_bridge/src/push/push_notification_content_builder.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const contentBuilder = PushNotificationContentBuilder();

  group("extractNotificationData", () {
    test("maps question.asked and permission.asked to ai_interaction", () {
      const questionEvent = SesoriSseEvent.questionAsked(
        id: "q-1",
        sessionID: "session-a",
        displaySessionId: null,
        questions: [QuestionInfo(question: "Continue?", header: "Prompt")],
      );
      const permissionEvent = SesoriSseEvent.permissionAsked(
        requestID: "r-1",
        sessionID: "session-a",
        displaySessionId: null,
        tool: "bash",
        description: "Run command",
      );

      expect(contentBuilder.extractNotificationData(questionEvent)?.category, NotificationCategory.aiInteraction);
      expect(contentBuilder.extractNotificationData(permissionEvent)?.category, NotificationCategory.aiInteraction);
    });

    test("uses content-safe copy for question and permission notifications", () {
      const questionEvent = SesoriSseEvent.questionAsked(
        id: "q-1",
        sessionID: "session-a",
        displaySessionId: null,
        questions: [
          QuestionInfo(
            question: "one two three four five six seven eight nine ten eleven twelve",
            header: "Prompt",
          ),
        ],
      );
      final permissionEvent = SesoriSseEvent.permissionAsked(
        requestID: "r-1",
        sessionID: "session-a",
        displaySessionId: null,
        tool: "/private/project/destructive-script",
        description: List.filled(200, "x").join(),
      );
      const emptyPermissionEvent = SesoriSseEvent.permissionAsked(
        requestID: "r-2",
        sessionID: "session-a",
        displaySessionId: null,
        tool: "/private/project/destructive-script",
        description: "",
      );

      expect(
        contentBuilder.extractNotificationData(questionEvent)?.body,
        "The assistant is waiting for your response.",
      );
      expect(
        contentBuilder.extractNotificationData(permissionEvent)?.body,
        "The assistant requested permission.",
      );
      expect(
        contentBuilder.extractNotificationData(emptyPermissionEvent)?.body,
        "The assistant requested permission.",
      );
    });

    test("maps installation.update-available to system_update", () {
      const event = SesoriSseEvent.installationUpdateAvailable(version: "1.2.3");

      expect(contentBuilder.extractNotificationData(event)?.category, NotificationCategory.systemUpdate);
    });

    test("returns null for unsupported events", () {
      expect(contentBuilder.extractNotificationData(const SesoriSseEvent.serverHeartbeat()), isNull);
    });
  });

  group("buildNotificationPayload", () {
    test("includes session data and collapse key for session-scoped events", () {
      const event = SesoriSseEvent.questionAsked(
        id: "q-1",
        sessionID: "session-a",
        displaySessionId: null,
        questions: [QuestionInfo(question: "Ship it?", header: "Prompt")],
      );

      final data = contentBuilder.extractNotificationData(event)!;
      final sessionId = contentBuilder.extractSessionId(event);
      final payload = contentBuilder.buildNotificationPayload(
        category: data.category,
        eventType: data.eventType,
        title: data.title,
        body: data.body,
        collapseKey: "${data.category.id}-${sessionId ?? "global"}",
        sessionId: sessionId,
        projectId: null,
      );

      expect(payload.title, equals("Question requires input"));
      expect(payload.body, equals("The assistant is waiting for your response."));
      expect(payload.collapseKey, equals("ai_interaction-session-a"));
      expect(payload.data?.sessionId, equals("session-a"));
      expect(payload.data?.category, equals(NotificationCategory.aiInteraction));
      expect(payload.data?.eventType, equals(NotificationEventType.questionAsked));
    });

    test("omits session data for non-session events", () {
      const event = SesoriSseEvent.installationUpdateAvailable(version: "2.0.0");

      final data = contentBuilder.extractNotificationData(event)!;
      final sessionId = contentBuilder.extractSessionId(event);
      final payload = contentBuilder.buildNotificationPayload(
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

    test("omits path-based project identities and keeps opaque identities", () {
      final posixPayload = contentBuilder.buildNotificationPayload(
        category: NotificationCategory.sessionMessage,
        eventType: NotificationEventType.agentTurnCompleted,
        title: "Session completed",
        body: "Task completed",
        collapseKey: "session-a",
        sessionId: "session-a",
        projectId: "/private/project",
      );
      final windowsPayload = contentBuilder.buildNotificationPayload(
        category: NotificationCategory.sessionMessage,
        eventType: NotificationEventType.agentTurnCompleted,
        title: "Session completed",
        body: "Task completed",
        collapseKey: "session-b",
        sessionId: "session-b",
        projectId: r"C:\private\project",
      );
      final opaquePayload = contentBuilder.buildNotificationPayload(
        category: NotificationCategory.sessionMessage,
        eventType: NotificationEventType.agentTurnCompleted,
        title: "Session completed",
        body: "Task completed",
        collapseKey: "session-c",
        sessionId: "session-c",
        projectId: "project-1",
      );

      expect(posixPayload.data?.projectId, isNull);
      expect(windowsPayload.data?.projectId, isNull);
      expect(opaquePayload.data?.projectId, "project-1");
    });
  });

  group("extractSessionId", () {
    test("attributes a child session's permission to its display (root) session", () {
      const event = SesoriSseEvent.permissionAsked(
        requestID: "r-1",
        sessionID: "child",
        displaySessionId: "root",
        tool: "bash",
        description: "Run command",
      );

      expect(contentBuilder.extractSessionId(event), equals("root"));
    });

    test("falls back to sessionID when displaySessionId is null", () {
      const event = SesoriSseEvent.permissionAsked(
        requestID: "r-1",
        sessionID: "child",
        displaySessionId: null,
        tool: "bash",
        description: "Run command",
      );

      expect(contentBuilder.extractSessionId(event), equals("child"));
    });
  });
}

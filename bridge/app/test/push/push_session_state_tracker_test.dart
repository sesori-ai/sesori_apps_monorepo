import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PushSessionStateTracker", () {
    test("tracks session statuses from SesoriSessionStatus events", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.busy(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("session-a"), isFalse);
      expect(tracker.wasPreviouslyBusy("session-a"), isTrue);

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.retry(attempt: 2, message: "retry", next: 1000),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("session-a"), isFalse);
      expect(tracker.wasPreviouslyBusy("session-a"), isTrue);

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("session-a"), isTrue);
      expect(tracker.wasPreviouslyBusy("session-a"), isTrue);
    });

    test("tracks parent-child relationships from session created and updated", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "parent"),
        ),
      );
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "parent"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "child",
          status: SessionStatus.busy(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("parent"), isFalse);
      expect(tracker.resolveRootSessionId("child"), equals("parent"));

      tracker.handleEvent(
        SesoriSseEvent.sessionUpdated(
          info: _session(id: "child", parentID: null),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("parent"), isTrue);
      expect(tracker.resolveRootSessionId("child"), equals("child"));
    });

    test("tracks session titles from session created and updated", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "session-a", title: "Initial title"),
        ),
      );
      expect(tracker.getSessionTitle("session-a"), equals("Initial title"));

      tracker.handleEvent(
        SesoriSseEvent.sessionUpdated(
          info: _session(id: "session-a", title: "Updated title"),
        ),
      );
      expect(tracker.getSessionTitle("session-a"), equals("Updated title"));
    });

    test("tracks messageID to role from message updated events", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(id: "m-1", role: "assistant", sessionID: "session-a"),
        ),
      );

      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "part-1",
            sessionID: "session-a",
            messageID: "m-1",
            type: MessagePartType.text,
            text: "assistant text",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("session-a"), equals("assistant text"));
    });

    test("tracks latest assistant text only for assistant text parts", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(id: "assistant-msg", role: "assistant", sessionID: "session-a"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "part-1",
            sessionID: "session-a",
            messageID: "assistant-msg",
            type: MessagePartType.text,
            text: "first",
          ),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "part-2",
            sessionID: "session-a",
            messageID: "assistant-msg",
            type: MessagePartType.text,
            text: "latest",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("session-a"), equals("latest"));
    });

    test("tracks pending questions and clears on replied or rejected", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "session-a",
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );
      expect(tracker.hasPendingInteraction("session-a"), isTrue);

      tracker.handleEvent(
        const SesoriSseEvent.questionReplied(
          requestID: "q-1",
          sessionID: "session-a",
        ),
      );
      expect(tracker.hasPendingInteraction("session-a"), isFalse);

      tracker.handleEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-2",
          sessionID: "session-a",
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );
      expect(tracker.hasPendingInteraction("session-a"), isTrue);

      tracker.handleEvent(
        const SesoriSseEvent.questionRejected(
          requestID: "q-2",
          sessionID: "session-a",
        ),
      );
      expect(tracker.hasPendingInteraction("session-a"), isFalse);
    });

    test("tracks pending permissions using requestID to sessionID mapping", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        const SesoriSseEvent.permissionAsked(
          requestID: "req-1",
          sessionID: "session-a",
          tool: "bash",
          description: "run",
        ),
      );

      expect(tracker.hasPendingInteraction("session-a"), isTrue);

      tracker.handleEvent(
        const SesoriSseEvent.permissionReplied(
          requestID: "req-1",
          reply: "allow",
        ),
      );

      expect(tracker.hasPendingInteraction("session-a"), isFalse);
    });

    test("isSessionGroupFullyIdle is true only when session and direct children are idle", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child-1", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child-2", parentID: "root"),
        ),
      );

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "child-1",
          status: SessionStatus.busy(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("root"), isFalse);

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "child-1",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("root"), isTrue);
    });

    test("isSessionGroupFullyIdle returns false when a grandchild is busy", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "grandchild", parentID: "child"),
        ),
      );

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "grandchild",
          status: SessionStatus.busy(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("root"), isFalse);

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "grandchild",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("root"), isTrue);
    });

    test("hasPendingInteraction returns true for pending question or permission", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "session-a",
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );
      expect(tracker.hasPendingInteraction("session-a"), isTrue);

      tracker.handleEvent(
        const SesoriSseEvent.questionReplied(requestID: "q-1", sessionID: "session-a"),
      );
      expect(tracker.hasPendingInteraction("session-a"), isFalse);

      tracker.handleEvent(
        const SesoriSseEvent.permissionAsked(
          requestID: "req-1",
          sessionID: "session-a",
          tool: "bash",
          description: "run",
        ),
      );
      expect(tracker.hasPendingInteraction("session-a"), isTrue);
    });

    test("hasPendingInteraction includes direct child sessions", () {
      final tracker = PushSessionStateTracker();

      // Register parent and child.
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "parent"),
        ),
      );
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "parent"),
        ),
      );

      // No pending on either.
      expect(tracker.hasPendingInteraction("parent"), isFalse);

      // Question on child → parent group has pending interaction.
      tracker.handleEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-child",
          sessionID: "child",
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );
      expect(tracker.hasPendingInteraction("parent"), isTrue);
      expect(tracker.hasPendingInteraction("child"), isTrue);

      // Reply clears it.
      tracker.handleEvent(
        const SesoriSseEvent.questionReplied(requestID: "q-child", sessionID: "child"),
      );
      expect(tracker.hasPendingInteraction("parent"), isFalse);
    });

    test("hasPendingInteraction includes grandchild sessions", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "grandchild", parentID: "child"),
        ),
      );

      tracker.handleEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-grandchild",
          sessionID: "grandchild",
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );

      expect(tracker.hasPendingInteraction("root"), isTrue);

      tracker.handleEvent(
        const SesoriSseEvent.questionReplied(
          requestID: "q-grandchild",
          sessionID: "grandchild",
        ),
      );

      expect(tracker.hasPendingInteraction("root"), isFalse);
    });

    test("getSessionTitle returns cached title or null", () {
      final tracker = PushSessionStateTracker();

      expect(tracker.getSessionTitle("missing"), isNull);

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "session-a", title: "A title"),
        ),
      );

      expect(tracker.getSessionTitle("session-a"), equals("A title"));
    });

    test("getLatestAssistantText returns cached text or null", () {
      final tracker = PushSessionStateTracker();

      expect(tracker.getLatestAssistantText("session-a"), isNull);

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(id: "m-1", role: "assistant", sessionID: "session-a"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "p-1",
            sessionID: "session-a",
            messageID: "m-1",
            type: MessagePartType.text,
            text: "hello",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("session-a"), equals("hello"));
    });

    test("wasPreviouslyBusy true only when session was seen busy before idle", () {
      final tracker = PushSessionStateTracker();

      expect(tracker.wasPreviouslyBusy("session-a"), isFalse);

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.busy(),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.wasPreviouslyBusy("session-a"), isTrue);
    });

    test("reset clears all maps and state", () {
      final tracker = PushSessionStateTracker();

      tracker
        ..handleEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "root", title: "Root"),
          ),
        )
        ..handleEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "root"),
          ),
        )
        ..handleEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        )
        ..handleEvent(
          const SesoriSseEvent.questionAsked(
            id: "q-1",
            sessionID: "root",
            questions: [QuestionInfo(header: "h", question: "q")],
          ),
        )
        ..handleEvent(
          const SesoriSseEvent.permissionAsked(
            requestID: "req-1",
            sessionID: "root",
            tool: "bash",
            description: "run",
          ),
        )
        ..handleEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(id: "m-1", role: "assistant", sessionID: "root"),
          ),
        )
        ..handleEvent(
          const SesoriSseEvent.messagePartUpdated(
            part: MessagePart(
              id: "p-1",
              sessionID: "root",
              messageID: "m-1",
              type: MessagePartType.text,
              text: "latest",
            ),
          ),
        );

      tracker.reset();

      expect(tracker.isSessionGroupFullyIdle("root"), isTrue);
      expect(tracker.hasPendingInteraction("root"), isFalse);
      expect(tracker.getSessionTitle("root"), isNull);
      expect(tracker.getLatestAssistantText("root"), isNull);
      expect(tracker.wasPreviouslyBusy("root"), isFalse);
      expect(tracker.resolveRootSessionId("child"), equals("child"));
    });

    test("handleEvent processes events and updates state", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "root", title: "Root title"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
      );
      tracker.handleEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "root",
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("root"), isFalse);
      expect(tracker.hasPendingInteraction("root"), isTrue);
      expect(tracker.getSessionTitle("root"), equals("Root title"));
    });

    test("cleans up session state on session deleted", () {
      final tracker = PushSessionStateTracker();

      tracker
        ..handleEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "root", title: "Root"),
          ),
        )
        ..handleEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "root"),
          ),
        )
        ..handleEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        )
        ..handleEvent(
          const SesoriSseEvent.questionAsked(
            id: "q-1",
            sessionID: "root",
            questions: [QuestionInfo(header: "h", question: "q")],
          ),
        )
        ..handleEvent(
          const SesoriSseEvent.permissionAsked(
            requestID: "req-1",
            sessionID: "root",
            tool: "bash",
            description: "run",
          ),
        );

      tracker.handleEvent(
        SesoriSseEvent.sessionDeleted(
          info: _session(id: "root", title: "Root"),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle("root"), isTrue);
      expect(tracker.hasPendingInteraction("root"), isFalse);
      expect(tracker.getSessionTitle("root"), isNull);
      expect(tracker.wasPreviouslyBusy("root"), isFalse);
      expect(tracker.resolveRootSessionId("child"), equals("child"));
    });

    test("ignores message part updates with non-text type", () {
      final tracker = PushSessionStateTracker();

      tracker
        ..handleEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(id: "m-1", role: "assistant", sessionID: "session-a"),
          ),
        )
        ..handleEvent(
          const SesoriSseEvent.messagePartUpdated(
            part: MessagePart(
              id: "p-1",
              sessionID: "session-a",
              messageID: "m-1",
              type: MessagePartType.tool,
              text: "should be ignored",
            ),
          ),
        );

      expect(tracker.getLatestAssistantText("session-a"), isNull);
    });

    test("ignores message part updates for non-assistant messages", () {
      final tracker = PushSessionStateTracker();

      tracker
        ..handleEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(id: "m-1", role: "user", sessionID: "session-a"),
          ),
        )
        ..handleEvent(
          const SesoriSseEvent.messagePartUpdated(
            part: MessagePart(
              id: "p-1",
              sessionID: "session-a",
              messageID: "m-1",
              type: MessagePartType.text,
              text: "should be ignored",
            ),
          ),
        );

      expect(tracker.getLatestAssistantText("session-a"), isNull);
    });

    test("idle without prior busy does not mark session as previously busy", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.wasPreviouslyBusy("session-a"), isFalse);
      expect(tracker.isSessionGroupFullyIdle("session-a"), isTrue);
    });

    test("getSessionProjectId returns stored projectId after session upsert", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "x", projectID: "p1"),
        ),
      );

      expect(tracker.getSessionProjectId(sessionId: "x"), equals("p1"));
    });

    test("getSessionProjectId returns null for unknown sessionId", () {
      final tracker = PushSessionStateTracker();

      expect(tracker.getSessionProjectId(sessionId: "unknown"), isNull);
    });

    test("wasPreviouslyBusy returns true if only a descendant was busy", () {
      final tracker = PushSessionStateTracker();

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );

      // Only child goes busy, root never does.
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
      );

      // Root was never busy itself, but its descendant was.
      expect(tracker.wasPreviouslyBusy("root"), isTrue);
    });
  });
}

Session _session({
  required String id,
  String projectID = "project-a",
  String directory = "/tmp/project",
  String? parentID,
  String? title,
}) {
  return Session(
    id: id,
    projectID: projectID,
    directory: directory,
    parentID: parentID,
    title: title,
  );
}

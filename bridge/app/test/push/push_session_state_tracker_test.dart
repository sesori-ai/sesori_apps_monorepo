import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker_types.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PushSessionStateTracker", () {
    test("tracks session statuses from SesoriSessionStatus events", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "m-1",
            role: "assistant",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
          ),
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
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("session-a"), equals("assistant text"));
    });

    test("tracks latest assistant text only for assistant text parts", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "assistant-msg",
            role: "assistant",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
          ),
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
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
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
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("session-a"), equals("latest"));
    });

    test("tracks pending questions and clears on replied or rejected", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
          sessionID: "session-a",
          reply: "allow",
        ),
      );

      expect(tracker.hasPendingInteraction("session-a"), isFalse);
    });

    test("isSessionGroupFullyIdle is true only when session and direct children are idle", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

      expect(tracker.getSessionTitle("missing"), isNull);

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "session-a", title: "A title"),
        ),
      );

      expect(tracker.getSessionTitle("session-a"), equals("A title"));
    });

    test("getLatestAssistantText returns cached text or null", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      expect(tracker.getLatestAssistantText("session-a"), isNull);

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "m-1",
            role: "assistant",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
          ),
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
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("session-a"), equals("hello"));
    });

    test("wasPreviouslyBusy true only when session was seen busy before idle", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
            info: Message(
              id: "m-1",
              role: "assistant",
              sessionID: "root",
              agent: null,
              modelID: null,
              providerID: null,
            ),
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
              tool: null,
              state: null,
              prompt: null,
              description: null,
              agent: null,
              agentName: null,
              attempt: null,
              retryError: null,
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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

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

    test("session delete removes only indexed message roles for that session", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "other")));
      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "root-msg",
            role: "assistant",
            sessionID: "root",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "other-msg",
            role: "assistant",
            sessionID: "other",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );

      tracker.handleEvent(SesoriSseEvent.sessionDeleted(info: _session(id: "root")));

      expect(tracker.createTelemetrySnapshot().messageRoleCount, equals(1));

      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "root-part",
            sessionID: "root",
            messageID: "root-msg",
            type: MessagePartType.text,
            text: "removed",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "other-part",
            sessionID: "other",
            messageID: "other-msg",
            type: MessagePartType.text,
            text: "survived delete",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("root"), isNull);
      expect(tracker.getLatestAssistantText("other"), equals("survived delete"));
    });

    test("ignores message part updates with non-text type", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker
        ..handleEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(
              id: "m-1",
              role: "assistant",
              sessionID: "session-a",
              agent: null,
              modelID: null,
              providerID: null,
            ),
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
              tool: null,
              state: null,
              prompt: null,
              description: null,
              agent: null,
              agentName: null,
              attempt: null,
              retryError: null,
            ),
          ),
        );

      expect(tracker.getLatestAssistantText("session-a"), isNull);
    });

    test("ignores message part updates for non-assistant messages", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker
        ..handleEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(
              id: "m-1",
              role: "user",
              sessionID: "session-a",
              agent: null,
              modelID: null,
              providerID: null,
            ),
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
              tool: null,
              state: null,
              prompt: null,
              description: null,
              agent: null,
              agentName: null,
              attempt: null,
              retryError: null,
            ),
          ),
        );

      expect(tracker.getLatestAssistantText("session-a"), isNull);
    });

    test("idle without prior busy does not mark session as previously busy", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

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
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "x", projectID: "p1"),
        ),
      );

      expect(tracker.getSessionProjectId(sessionId: "x"), equals("p1"));
    });

    test("getSessionProjectId returns null for unknown sessionId", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      expect(tracker.getSessionProjectId(sessionId: "unknown"), isNull);
    });

    test("wasPreviouslyBusy returns true if only a descendant was busy", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

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

    test("projectsSummary establishes parent-child links for status-only sessions", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      // Sessions created implicitly via status events (e.g., after bridge restart).
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
      );

      // Without a projects.summary, the child appears to be a root.
      expect(tracker.resolveRootSessionId("child"), equals("child"));

      // projects.summary arrives and establishes the parent link.
      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(id: "root", mainAgentRunning: true, childSessionIds: ["child"]),
              ],
            ),
          ],
        ),
      );

      expect(tracker.resolveRootSessionId("child"), equals("root"));
      expect(tracker.isSessionGroupFullyIdle("root"), isFalse);
    });

    test("projectsSummary does not overwrite parent links from sessionCreated", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      // Proper creation events establish parent link.
      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );

      // A summary with stale or different data should not overwrite.
      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(id: "other-root", mainAgentRunning: true, childSessionIds: ["child"]),
              ],
            ),
          ],
        ),
      );

      // Parent link from sessionCreated is preserved.
      expect(tracker.resolveRootSessionId("child"), equals("root"));
    });

    test("root session gets projectId from projects summary", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "proj-a",
              activeSessions: [
                ActiveSession(id: "sess-root", mainAgentRunning: true),
              ],
            ),
          ],
        ),
      );

      expect(tracker.getSessionProjectId(sessionId: "sess-root"), equals("proj-a"));
    });

    test("child session gets projectId from projects summary", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "proj-a",
              activeSessions: [
                ActiveSession(
                  id: "sess-root",
                  mainAgentRunning: true,
                  childSessionIds: ["sess-child"],
                ),
              ],
            ),
          ],
        ),
      );

      expect(tracker.getSessionProjectId(sessionId: "sess-child"), equals("proj-a"));
    });

    test("projects summary overwrites existing projectId", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "sess-1", projectID: "proj-old"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "proj-new",
              activeSessions: [
                ActiveSession(id: "sess-1", mainAgentRunning: true),
              ],
            ),
          ],
        ),
      );

      expect(tracker.getSessionProjectId(sessionId: "sess-1"), equals("proj-new"));
    });

    test("projectsSummary establishes multi-level hierarchy for status-only sessions", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      // Three sessions known only via status events.
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "grandchild", status: SessionStatus.busy()),
      );

      // Two summaries establish root→child and child→grandchild.
      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(id: "root", mainAgentRunning: true, childSessionIds: ["child"]),
                ActiveSession(id: "child", mainAgentRunning: true, childSessionIds: ["grandchild"]),
              ],
            ),
          ],
        ),
      );

      expect(tracker.resolveRootSessionId("grandchild"), equals("root"));
      expect(tracker.resolveRootSessionId("child"), equals("root"));

      // Grandchild busy keeps entire group non-idle.
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
      );
      expect(tracker.isSessionGroupFullyIdle("root"), isFalse);

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "grandchild", status: SessionStatus.idle()),
      );
      expect(tracker.isSessionGroupFullyIdle("root"), isTrue);
    });

    test("resolveRootSessionId stops at child when parent entry is missing", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      // Child has parentId set via sessionCreated, but parent was never seen.
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "unknown-parent"),
        ),
      );

      // Cannot walk up because parent is not in _sessions.
      expect(tracker.resolveRootSessionId("child"), equals("child"));

      // Once the parent appears (e.g., via a summary), the link works.
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(
          sessionID: "unknown-parent",
          status: SessionStatus.busy(),
        ),
      );
      expect(tracker.resolveRootSessionId("child"), equals("unknown-parent"));
    });

    test("prunes an idle subtree and reports telemetry snapshot data", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      clock.advance(const Duration(seconds: 1));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      clock.advance(const Duration(seconds: 1));
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
      );
      clock.advance(const Duration(seconds: 1));
      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "assistant-msg",
            role: "assistant",
            sessionID: "child",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "part-1",
            sessionID: "child",
            messageID: "assistant-msg",
            type: MessagePartType.text,
            text: "latest child reply",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );
      clock.advance(const Duration(seconds: 1));
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
      );

      clock.advance(const Duration(minutes: 31));

      expect(tracker.findPrunableRootSessionIds(), equals(["root"]));

      final snapshot = tracker.createTelemetrySnapshot();
      expect(snapshot.sessionCount, equals(2));
      expect(snapshot.rootSessionCount, equals(1));
      expect(snapshot.previouslyBusyCount, equals(1));
      expect(snapshot.latestAssistantTextCount, equals(1));
      expect(snapshot.messageRoleCount, equals(1));
      expect(snapshot.assistantMessageRoleCount, equals(1));
      expect(snapshot.oldestSessionActivityAt, isNotNull);
      expect(snapshot.oldestMessageRoleUpdatedAt, isNotNull);
      expect(snapshot.prunableRoots, hasLength(1));
      expect(snapshot.prunableRoots.single.rootSessionId, equals("root"));
      expect(
        snapshot.prunableRoots.single.retainedSessionCount,
        equals(2),
      );

      tracker.clearLatestAssistantTextForRootSubtree(rootSessionId: "root");
      expect(tracker.getLatestAssistantText("child"), isNull);

      final pruneResult = tracker.pruneRootSubtree(rootSessionId: "root");
      expect(pruneResult.rootSessionId, equals("root"));
      expect(pruneResult.removedSessionCount, equals(2));
      expect(pruneResult.removedMessageRoleCount, equals(1));
      expect(pruneResult.removedPermissionMappingCount, equals(0));
      expect(tracker.createTelemetrySnapshot().sessionCount, equals(0));
      expect(tracker.resolveRootSessionId("child"), equals("child"));
    });

    test("subtree prune removes only indexed message roles for that subtree", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root-a")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child-a", parentID: "root-a"),
        ),
      );
      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root-b")));

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "pruned-msg",
            role: "assistant",
            sessionID: "child-a",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "survivor-msg",
            role: "assistant",
            sessionID: "root-b",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );

      final pruneResult = tracker.pruneRootSubtree(rootSessionId: "root-a");
      expect(pruneResult.removedSessionCount, equals(2));
      expect(pruneResult.removedMessageRoleCount, equals(1));
      expect(tracker.createTelemetrySnapshot().messageRoleCount, equals(1));

      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "pruned-part",
            sessionID: "child-a",
            messageID: "pruned-msg",
            type: MessagePartType.text,
            text: "should stay pruned",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "survivor-part",
            sessionID: "root-b",
            messageID: "survivor-msg",
            type: MessagePartType.text,
            text: "survivor text",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("child-a"), isNull);
      expect(tracker.getLatestAssistantText("root-b"), equals("survivor text"));
    });

    test("does not prune busy or pending roots before they become idle long enough", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
      );

      clock.advance(const Duration(minutes: 40));
      expect(tracker.findPrunableRootSessionIds(), isEmpty);

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
      );
      tracker.handleEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "child",
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );

      clock.advance(const Duration(minutes: 40));
      expect(tracker.findPrunableRootSessionIds(), isEmpty);

      tracker.handleEvent(
        const SesoriSseEvent.questionReplied(requestID: "q-1", sessionID: "child"),
      );

      clock.advance(const Duration(minutes: 31));
      expect(tracker.findPrunableRootSessionIds(), equals(["root"]));
    });

    test("late events can rebuild state after a subtree prune", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
      );

      clock.advance(const Duration(minutes: 31));
      tracker.pruneRootSubtree(rootSessionId: "root");

      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
      );
      expect(tracker.isSessionGroupFullyIdle("child"), isFalse);
      expect(tracker.resolveRootSessionId("child"), equals("child"));

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "late-msg",
            role: "assistant",
            sessionID: "child",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "late-part",
            sessionID: "child",
            messageID: "late-msg",
            type: MessagePartType.text,
            text: "rebuilt text",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );
      expect(tracker.getLatestAssistantText("child"), equals("rebuilt text"));

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(
        SesoriSseEvent.sessionUpdated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      expect(tracker.resolveRootSessionId("child"), equals("root"));
    });

    test("prunes stale message roles and enforces the hard cap", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "expired-msg",
            role: "assistant",
            sessionID: "expired-session",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );

      clock.advance(const Duration(minutes: 31));
      tracker.pruneMessageRoleMetadata();
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "expired-part",
            sessionID: "expired-session",
            messageID: "expired-msg",
            type: MessagePartType.text,
            text: "ignored",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );
      expect(tracker.getLatestAssistantText("expired-session"), isNull);

      for (var index = 0; index <= PushSessionMaintenancePolicy.messageRoleHardCap; index++) {
        tracker.handleEvent(
          SesoriSseEvent.messageUpdated(
            info: Message(
              id: "msg-$index",
              role: "assistant",
              sessionID: "session-$index",
              agent: null,
              modelID: null,
              providerID: null,
            ),
          ),
        );
        clock.advance(const Duration(milliseconds: 1));
      }

      tracker.pruneMessageRoleMetadata();
      expect(
        tracker.createTelemetrySnapshot().messageRoleCount,
        equals(PushSessionMaintenancePolicy.messageRoleHardCap),
      );

      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "oldest-part",
            sessionID: "session-0",
            messageID: "msg-0",
            type: MessagePartType.text,
            text: "should stay pruned",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );
      expect(tracker.getLatestAssistantText("session-0"), isNull);

      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "newest-part",
            sessionID: "session-10000",
            messageID: "msg-10000",
            type: MessagePartType.text,
            text: "latest kept role",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );
      expect(tracker.getLatestAssistantText("session-10000"), equals("latest kept role"));
    });

    test("active assistant message parts refresh role retention timestamps", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "stream-msg",
            role: "assistant",
            sessionID: "stream-session",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );

      clock.advance(const Duration(minutes: 29));
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "stream-part-1",
            sessionID: "stream-session",
            messageID: "stream-msg",
            type: MessagePartType.text,
            text: "still streaming",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      clock.advance(const Duration(minutes: 2));
      tracker.pruneMessageRoleMetadata();
      tracker.handleEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "stream-part-2",
            sessionID: "stream-session",
            messageID: "stream-msg",
            type: MessagePartType.text,
            text: "fresh after prune",
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        ),
      );

      expect(tracker.getLatestAssistantText("stream-session"), equals("fresh after prune"));
    });

    test("subtree prune helpers are safe no-ops after a prior prune", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );

      final firstPrune = tracker.pruneRootSubtree(rootSessionId: "root");
      expect(firstPrune.removedSessionCount, equals(2));

      tracker.clearLatestAssistantTextForRootSubtree(rootSessionId: "root");
      final secondPrune = tracker.pruneRootSubtree(rootSessionId: "root");
      expect(secondPrune.removedSessionCount, equals(0));
      expect(secondPrune.removedMessageRoleCount, equals(0));
      expect(secondPrune.removedPermissionMappingCount, equals(0));
      expect(tracker.findPrunableRootSessionIds(), isEmpty);
    });

    test("stale project summaries do not break reparented prune roots", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root-a")));
      tracker.handleEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root-b")));
      tracker.handleEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root-a"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
      );
      tracker.handleEvent(
        SesoriSseEvent.sessionUpdated(
          info: _session(id: "child", parentID: "root-b"),
        ),
      );
      tracker.handleEvent(
        const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
      );

      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(id: "root-a", mainAgentRunning: false, childSessionIds: ["child"]),
              ],
            ),
          ],
        ),
      );

      expect(tracker.resolveRootSessionId("child"), equals("root-b"));

      clock.advance(const Duration(minutes: 31));
      final pruneResult = tracker.pruneRootSubtree(rootSessionId: "root-a");
      expect(pruneResult.removedSessionCount, equals(1));
      expect(tracker.resolveRootSessionId("child"), equals("root-b"));
      expect(tracker.findPrunableRootSessionIds(), contains("root-b"));
    });

    test("unknown session deletes clear stale parent links so summaries can repair them", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        SesoriSseEvent.sessionUpdated(
          info: _session(id: "child", parentID: "missing-root"),
        ),
      );
      expect(tracker.resolveRootSessionId("child"), equals("child"));

      tracker.handleEvent(
        SesoriSseEvent.sessionDeleted(info: _session(id: "missing-root")),
      );

      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(id: "repaired-root", mainAgentRunning: false, childSessionIds: ["child"]),
              ],
            ),
          ],
        ),
      );

      expect(tracker.resolveRootSessionId("child"), equals("repaired-root"));
    });

    test("projectsSummary-only roots receive timestamps and become prunable", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(id: "root", mainAgentRunning: false, childSessionIds: ["child"]),
              ],
            ),
          ],
        ),
      );

      clock.advance(const Duration(minutes: 31));

      expect(tracker.findPrunableRootSessionIds(), equals(["root"]));
    });
  });
}

class _FakeClock {
  DateTime _current;

  _FakeClock({required DateTime initial}) : _current = initial;

  DateTime now() {
    return _current;
  }

  void advance(Duration delta) {
    _current = _current.add(delta);
  }
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
    time: null,
    summary: null,
    pullRequest: null,
  );
}

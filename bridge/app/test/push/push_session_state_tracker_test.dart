import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PushSessionStateTracker", () {
    test("tracks session statuses from SesoriSessionStatus events", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.busy(since: null),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "session-a"), isFalse);
      expect(tracker.wasPreviouslyBusy(sessionId: "session-a"), isTrue);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.retry(attempt: 2, message: "retry", next: 1000, since: null),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "session-a"), isFalse);
      expect(tracker.wasPreviouslyBusy(sessionId: "session-a"), isTrue);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "session-a"), isTrue);
      expect(tracker.wasPreviouslyBusy(sessionId: "session-a"), isTrue);
    });

    test("tracks parent-child relationships from session created and updated", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "parent"),
        ),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "parent"),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "child",
          status: SessionStatus.busy(since: null),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "parent"), isFalse);
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("parent"));

      tracker.handleEvent(
        event: SesoriSseEvent.sessionUpdated(
          info: _session(id: "child", parentID: null),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "parent"), isTrue);
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("child"));
    });

    test("tracks messageID to role from message updated events", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "m-1",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );

      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "part-1",
            sessionID: "session-a",
            messageID: "m-1",
            text: "assistant text",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText(sessionId: "session-a"), equals("assistant text"));
    });

    test("tracks latest assistant text only for assistant text parts", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "assistant-msg",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "part-1",
            sessionID: "session-a",
            messageID: "assistant-msg",
            text: "first",
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "part-2",
            sessionID: "session-a",
            messageID: "assistant-msg",
            text: "latest",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText(sessionId: "session-a"), equals("latest"));

      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "system-msg",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
            sender: MessageSender.system,
            time: null,
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "part-system",
            sessionID: "session-a",
            messageID: "system-msg",
            text: "automation",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText(sessionId: "session-a"), equals("latest"));
    });

    test("tracks pending questions and clears on replied or rejected", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "session-a",
          displaySessionId: null,
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );
      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isTrue);

      tracker.handleEvent(
        event: const SesoriSseEvent.questionReplied(
          requestID: "q-1",
          sessionID: "session-a",
          displaySessionId: null,
        ),
      );
      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isFalse);

      tracker.handleEvent(
        event: const SesoriSseEvent.questionAsked(
          id: "q-2",
          sessionID: "session-a",
          displaySessionId: null,
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );
      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isTrue);

      tracker.handleEvent(
        event: const SesoriSseEvent.questionRejected(
          requestID: "q-2",
          sessionID: "session-a",
          displaySessionId: null,
        ),
      );
      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isFalse);
    });

    test("tracks pending permissions and clears them on reply", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.permissionAsked(
          requestID: "req-1",
          sessionID: "session-a",
          displaySessionId: null,
          tool: "bash",
          description: "run",
        ),
      );

      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isTrue);

      tracker.handleEvent(
        event: const SesoriSseEvent.permissionReplied(
          requestID: "req-1",
          sessionID: "session-a",
          displaySessionId: null,
          reply: "allow",
        ),
      );

      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isFalse);
    });

    test("isSessionGroupFullyIdle is true only when session and direct children are idle", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child-1", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child-2", parentID: "root"),
        ),
      );

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "child-1",
          status: SessionStatus.busy(since: null),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isFalse);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "child-1",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isTrue);
    });

    test("isSessionGroupFullyIdle returns false when a grandchild is busy", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "grandchild", parentID: "child"),
        ),
      );

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "grandchild",
          status: SessionStatus.busy(since: null),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isFalse);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "grandchild",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isTrue);
    });

    test("hasPendingInteraction returns true for pending question or permission", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "session-a",
          displaySessionId: null,
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );
      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isTrue);

      tracker.handleEvent(
        event: const SesoriSseEvent.questionReplied(requestID: "q-1", sessionID: "session-a", displaySessionId: null),
      );
      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isFalse);

      tracker.handleEvent(
        event: const SesoriSseEvent.permissionAsked(
          requestID: "req-1",
          sessionID: "session-a",
          displaySessionId: null,
          tool: "bash",
          description: "run",
        ),
      );
      expect(tracker.hasPendingInteraction(sessionId: "session-a"), isTrue);
    });

    test("hasPendingInteraction includes direct child sessions", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      // Register parent and child.
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "parent"),
        ),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "parent"),
        ),
      );

      // No pending on either.
      expect(tracker.hasPendingInteraction(sessionId: "parent"), isFalse);

      // Question on child → parent group has pending interaction.
      tracker.handleEvent(
        event: const SesoriSseEvent.questionAsked(
          id: "q-child",
          sessionID: "child",
          displaySessionId: null,
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );
      expect(tracker.hasPendingInteraction(sessionId: "parent"), isTrue);
      expect(tracker.hasPendingInteraction(sessionId: "child"), isTrue);

      // Reply clears it.
      tracker.handleEvent(
        event: const SesoriSseEvent.questionReplied(requestID: "q-child", sessionID: "child", displaySessionId: null),
      );
      expect(tracker.hasPendingInteraction(sessionId: "parent"), isFalse);
    });

    test("hasPendingInteraction includes grandchild sessions", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "grandchild", parentID: "child"),
        ),
      );

      tracker.handleEvent(
        event: const SesoriSseEvent.questionAsked(
          id: "q-grandchild",
          sessionID: "grandchild",
          displaySessionId: null,
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );

      expect(tracker.hasPendingInteraction(sessionId: "root"), isTrue);

      tracker.handleEvent(
        event: const SesoriSseEvent.questionReplied(
          requestID: "q-grandchild",
          sessionID: "grandchild",
          displaySessionId: null,
        ),
      );

      expect(tracker.hasPendingInteraction(sessionId: "root"), isFalse);
    });

    test("getLatestAssistantText returns cached text or null", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      expect(tracker.getLatestAssistantText(sessionId: "session-a"), isNull);

      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "m-1",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "p-1",
            sessionID: "session-a",
            messageID: "m-1",
            text: "hello",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText(sessionId: "session-a"), equals("hello"));
    });

    test("wasPreviouslyBusy true only when session was seen busy before idle", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      expect(tracker.wasPreviouslyBusy(sessionId: "session-a"), isFalse);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.busy(since: null),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.wasPreviouslyBusy(sessionId: "session-a"), isTrue);
    });

    test("handleEvent processes events and updates state", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "root", title: "Root title"),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy(since: null)),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "root",
          displaySessionId: null,
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isFalse);
      expect(tracker.hasPendingInteraction(sessionId: "root"), isTrue);
    });

    test("cleans up session state on session deleted", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker
        ..handleEvent(
          event: SesoriSseEvent.sessionCreated(
            info: _session(id: "root", title: "Root"),
          ),
        )
        ..handleEvent(
          event: SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "root"),
          ),
        )
        ..handleEvent(
          event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy(since: null)),
        )
        ..handleEvent(
          event: const SesoriSseEvent.questionAsked(
            id: "q-1",
            sessionID: "root",
            displaySessionId: null,
            questions: [QuestionInfo(header: "h", question: "q")],
          ),
        )
        ..handleEvent(
          event: const SesoriSseEvent.permissionAsked(
            requestID: "req-1",
            sessionID: "root",
            displaySessionId: null,
            tool: "bash",
            description: "run",
          ),
        );

      tracker.handleEvent(
        event: SesoriSseEvent.sessionDeleted(
          info: _session(id: "root", title: "Root"),
        ),
      );

      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isTrue);
      expect(tracker.hasPendingInteraction(sessionId: "root"), isFalse);
      expect(tracker.wasPreviouslyBusy(sessionId: "root"), isFalse);
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("child"));
    });

    test("session delete removes only indexed message roles for that session", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "other")),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "root-msg",
            sessionID: "root",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "other-msg",
            sessionID: "other",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );

      tracker.handleEvent(
        event: SesoriSseEvent.sessionDeleted(info: _session(id: "root")),
      );

      expect(tracker.messageRoleCount, equals(1));

      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "root-part",
            sessionID: "root",
            messageID: "root-msg",
            text: "removed",
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "other-part",
            sessionID: "other",
            messageID: "other-msg",
            text: "survived delete",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText(sessionId: "root"), isNull);
      expect(tracker.getLatestAssistantText(sessionId: "other"), equals("survived delete"));
    });

    test("ignores message part updates with non-text type", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker
        ..handleEvent(
          event: const SesoriSseEvent.messageUpdated(
            info: Message.assistant(
              id: "m-1",
              sessionID: "session-a",
              agent: null,
              modelID: null,
              providerID: null,
              time: null,
            ),
          ),
        )
        ..handleEvent(
          event: const SesoriSseEvent.messagePartUpdated(
            part: MessagePart.tool(
              id: "p-1",
              sessionID: "session-a",
              messageID: "m-1",
            ),
          ),
        );

      expect(tracker.getLatestAssistantText(sessionId: "session-a"), isNull);
    });

    test("ignores message part updates for non-assistant messages", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker
        ..handleEvent(
          event: const SesoriSseEvent.messageUpdated(
            info: Message.user(
              invocation: null,
              promptId: null,
              id: "m-1",
              sessionID: "session-a",
              agent: null,
              time: null,
            ),
          ),
        )
        ..handleEvent(
          event: const SesoriSseEvent.messagePartUpdated(
            part: MessagePart.text(
              id: "p-1",
              sessionID: "session-a",
              messageID: "m-1",
              text: "should be ignored",
            ),
          ),
        );

      expect(tracker.getLatestAssistantText(sessionId: "session-a"), isNull);
    });

    test("idle without prior busy does not mark session as previously busy", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.idle(),
        ),
      );

      expect(tracker.wasPreviouslyBusy(sessionId: "session-a"), isFalse);
      expect(tracker.isSessionGroupFullyIdle(sessionId: "session-a"), isTrue);
    });

    test("getSessionProjectId returns stored projectId after session upsert", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
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
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );

      // Only child goes busy, root never does.
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy(since: null)),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
      );

      // Root was never busy itself, but its descendant was.
      expect(tracker.wasPreviouslyBusy(sessionId: "root"), isTrue);
    });

    test("projectsSummary establishes parent-child links for status-only sessions", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      // Sessions created implicitly via status events (e.g., after bridge restart).
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy(since: null)),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy(since: null)),
      );

      // Without a projects.summary, the child appears to be a root.
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("child"));

      // projects.summary arrives and establishes the parent link.
      tracker.handleEvent(
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(
                  id: "root",
                  mainAgentRunning: true,
                  childSessionIds: ["child"],
                  lastUserActivityAt: null,
                  updatedAt: null,
                ),
              ],
            ),
          ],
        ),
      );

      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("root"));
      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isFalse);
    });

    test("projectsSummary does not overwrite parent links from sessionCreated", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      // Proper creation events establish parent link.
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );

      // A summary with stale or different data should not overwrite.
      tracker.handleEvent(
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(
                  id: "other-root",
                  mainAgentRunning: true,
                  childSessionIds: ["child"],
                  lastUserActivityAt: null,
                  updatedAt: null,
                ),
              ],
            ),
          ],
        ),
      );

      // Parent link from sessionCreated is preserved.
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("root"));
    });

    test("root session gets projectId from projects summary", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "proj-a",
              activeSessions: [
                ActiveSession(id: "sess-root", mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
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
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "proj-a",
              activeSessions: [
                ActiveSession(
                  id: "sess-root",
                  mainAgentRunning: true,
                  childSessionIds: ["sess-child"],
                  lastUserActivityAt: null,
                  updatedAt: null,
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
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "sess-1", projectID: "proj-old"),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "proj-new",
              activeSessions: [
                ActiveSession(id: "sess-1", mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
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
        event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy(since: null)),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy(since: null)),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "grandchild", status: SessionStatus.busy(since: null)),
      );

      // Two summaries establish root→child and child→grandchild.
      tracker.handleEvent(
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(
                  id: "root",
                  mainAgentRunning: true,
                  childSessionIds: ["child"],
                  lastUserActivityAt: null,
                  updatedAt: null,
                ),
                ActiveSession(
                  id: "child",
                  mainAgentRunning: true,
                  childSessionIds: ["grandchild"],
                  lastUserActivityAt: null,
                  updatedAt: null,
                ),
              ],
            ),
          ],
        ),
      );

      expect(tracker.resolveRootSessionId(sessionId: "grandchild"), equals("root"));
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("root"));

      // Grandchild busy keeps entire group non-idle.
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
      );
      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isFalse);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "grandchild", status: SessionStatus.idle()),
      );
      expect(tracker.isSessionGroupFullyIdle(sessionId: "root"), isTrue);
    });

    test("resolveRootSessionId stops at child when parent entry is missing", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      // Child has parentId set via sessionCreated, but parent was never seen.
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "unknown-parent"),
        ),
      );

      // Cannot walk up because parent is not in _sessions.
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("child"));

      // Once the parent appears (e.g., via a summary), the link works.
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "unknown-parent",
          status: SessionStatus.busy(since: null),
        ),
      );
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("unknown-parent"));
    });

    test("prunes an idle subtree", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      clock.advance(const Duration(seconds: 1));
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      clock.advance(const Duration(seconds: 1));
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy(since: null)),
      );
      clock.advance(const Duration(seconds: 1));
      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "assistant-msg",
            sessionID: "child",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "part-1",
            sessionID: "child",
            messageID: "assistant-msg",
            text: "latest child reply",
          ),
        ),
      );
      clock.advance(const Duration(seconds: 1));
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
      );

      clock.advance(const Duration(minutes: 31));

      expect(tracker.findPrunableRoots(), equals(["root"]));

      expect(tracker.sessionCount, equals(2));
      expect(tracker.messageRoleCount, equals(1));

      tracker.clearLatestAssistantTextForRootSubtree(rootSessionId: "root");
      expect(tracker.getLatestAssistantText(sessionId: "child"), isNull);

      expect(tracker.pruneRootSubtree(rootSessionId: "root"), unorderedEquals(["root", "child"]));
      expect(tracker.sessionCount, equals(0));
      expect(tracker.messageRoleCount, equals(0));
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("child"));
    });

    test("subtree prune removes only indexed message roles for that subtree", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root-a")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child-a", parentID: "root-a"),
        ),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root-b")),
      );

      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "pruned-msg",
            sessionID: "child-a",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "survivor-msg",
            sessionID: "root-b",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );

      expect(tracker.pruneRootSubtree(rootSessionId: "root-a"), hasLength(2));
      expect(tracker.messageRoleCount, equals(1));

      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "pruned-part",
            sessionID: "child-a",
            messageID: "pruned-msg",
            text: "should stay pruned",
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "survivor-part",
            sessionID: "root-b",
            messageID: "survivor-msg",
            text: "survivor text",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText(sessionId: "child-a"), isNull);
      expect(tracker.getLatestAssistantText(sessionId: "root-b"), equals("survivor text"));
    });

    test("does not prune busy or pending roots before they become idle long enough", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy(since: null)),
      );

      clock.advance(const Duration(minutes: 40));
      expect(tracker.findPrunableRoots(), isEmpty);

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "child",
          displaySessionId: null,
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );

      clock.advance(const Duration(minutes: 40));
      expect(tracker.findPrunableRoots(), isEmpty);

      tracker.handleEvent(
        event: const SesoriSseEvent.questionReplied(requestID: "q-1", sessionID: "child", displaySessionId: null),
      );

      clock.advance(const Duration(minutes: 31));
      expect(tracker.findPrunableRoots(), equals(["root"]));
    });

    test("late events can rebuild state after a subtree prune", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy(since: null)),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
      );

      clock.advance(const Duration(minutes: 31));
      tracker.pruneRootSubtree(rootSessionId: "root");

      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy(since: null)),
      );
      expect(tracker.isSessionGroupFullyIdle(sessionId: "child"), isFalse);
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("child"));

      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "late-msg",
            sessionID: "child",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "late-part",
            sessionID: "child",
            messageID: "late-msg",
            text: "rebuilt text",
          ),
        ),
      );
      expect(tracker.getLatestAssistantText(sessionId: "child"), equals("rebuilt text"));

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionUpdated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("root"));
    });

    test("prunes stale message roles and enforces the hard cap", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "expired-msg",
            sessionID: "expired-session",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );

      clock.advance(const Duration(minutes: 31));
      tracker.pruneMessageRoleMetadata();
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "expired-part",
            sessionID: "expired-session",
            messageID: "expired-msg",
            text: "ignored",
          ),
        ),
      );
      expect(tracker.getLatestAssistantText(sessionId: "expired-session"), isNull);

      for (var index = 0; index <= PushSessionMaintenancePolicy.messageRoleHardCap; index++) {
        tracker.handleEvent(
          event: SesoriSseEvent.messageUpdated(
            info: Message.assistant(
              id: "msg-$index",
              sessionID: "session-$index",
              agent: null,
              modelID: null,
              providerID: null,
              time: null,
            ),
          ),
        );
        clock.advance(const Duration(milliseconds: 1));
      }

      tracker.pruneMessageRoleMetadata();
      expect(
        tracker.messageRoleCount,
        equals(PushSessionMaintenancePolicy.messageRoleHardCap),
      );

      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "oldest-part",
            sessionID: "session-0",
            messageID: "msg-0",
            text: "should stay pruned",
          ),
        ),
      );
      expect(tracker.getLatestAssistantText(sessionId: "session-0"), isNull);

      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "newest-part",
            sessionID: "session-10000",
            messageID: "msg-10000",
            text: "latest kept role",
          ),
        ),
      );
      expect(tracker.getLatestAssistantText(sessionId: "session-10000"), equals("latest kept role"));
    });

    test("active assistant message parts refresh role retention timestamps", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "stream-msg",
            sessionID: "stream-session",
            agent: null,
            modelID: null,
            providerID: null,
            time: null,
          ),
        ),
      );

      clock.advance(const Duration(minutes: 29));
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "stream-part-1",
            sessionID: "stream-session",
            messageID: "stream-msg",
            text: "still streaming",
          ),
        ),
      );

      clock.advance(const Duration(minutes: 2));
      tracker.pruneMessageRoleMetadata();
      tracker.handleEvent(
        event: const SesoriSseEvent.messagePartUpdated(
          part: MessagePart.text(
            id: "stream-part-2",
            sessionID: "stream-session",
            messageID: "stream-msg",
            text: "fresh after prune",
          ),
        ),
      );

      expect(tracker.getLatestAssistantText(sessionId: "stream-session"), equals("fresh after prune"));
    });

    test("subtree prune helpers are safe no-ops after a prior prune", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );

      expect(tracker.pruneRootSubtree(rootSessionId: "root"), hasLength(2));

      tracker.clearLatestAssistantTextForRootSubtree(rootSessionId: "root");
      expect(tracker.pruneRootSubtree(rootSessionId: "root"), isEmpty);
      expect(tracker.findPrunableRoots(), isEmpty);
    });

    test("stale project summaries do not break reparented prune roots", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root-a")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(info: _session(id: "root-b")),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root-a"),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy(since: null)),
      );
      tracker.handleEvent(
        event: SesoriSseEvent.sessionUpdated(
          info: _session(id: "child", parentID: "root-b"),
        ),
      );
      tracker.handleEvent(
        event: const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
      );

      tracker.handleEvent(
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(
                  id: "root-a",
                  mainAgentRunning: false,
                  childSessionIds: ["child"],
                  lastUserActivityAt: null,
                  updatedAt: null,
                ),
              ],
            ),
          ],
        ),
      );

      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("root-b"));

      clock.advance(const Duration(minutes: 31));
      expect(tracker.pruneRootSubtree(rootSessionId: "root-a"), equals(["root-a"]));
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("root-b"));
      expect(tracker.findPrunableRoots(), contains("root-b"));
    });

    test("unknown session deletes clear stale parent links so summaries can repair them", () {
      final tracker = PushSessionStateTracker(now: DateTime.now);

      tracker.handleEvent(
        event: SesoriSseEvent.sessionUpdated(
          info: _session(id: "child", parentID: "missing-root"),
        ),
      );
      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("child"));

      tracker.handleEvent(
        event: SesoriSseEvent.sessionDeleted(info: _session(id: "missing-root")),
      );

      tracker.handleEvent(
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(
                  id: "repaired-root",
                  mainAgentRunning: false,
                  childSessionIds: ["child"],
                  lastUserActivityAt: null,
                  updatedAt: null,
                ),
              ],
            ),
          ],
        ),
      );

      expect(tracker.resolveRootSessionId(sessionId: "child"), equals("repaired-root"));
    });

    test("projectsSummary-only roots receive timestamps and become prunable", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      tracker.handleEvent(
        event: const SesoriSseEvent.projectsSummary(
          projects: [
            ProjectActivitySummary(
              id: "project-a",
              activeSessions: [
                ActiveSession(
                  id: "root",
                  mainAgentRunning: false,
                  childSessionIds: ["child"],
                  lastUserActivityAt: null,
                  updatedAt: null,
                ),
              ],
            ),
          ],
        ),
      );

      clock.advance(const Duration(minutes: 31));

      expect(tracker.findPrunableRoots(), equals(["root"]));
    });

    test("replayed projects summary does not refresh prune age for existing roots", () {
      final clock = _FakeClock(initial: DateTime.utc(2026, 1, 1, 12));
      final tracker = PushSessionStateTracker(now: clock.now);

      const summaryEvent = SesoriSseEvent.projectsSummary(
        projects: [
          ProjectActivitySummary(
            id: "project-a",
            activeSessions: [
              ActiveSession(
                id: "root",
                mainAgentRunning: false,
                childSessionIds: ["child"],
                lastUserActivityAt: null,
                updatedAt: null,
              ),
            ],
          ),
        ],
      );

      tracker.handleEvent(event: summaryEvent);
      clock.advance(const Duration(minutes: 20));
      tracker.handleEvent(event: summaryEvent);
      clock.advance(const Duration(minutes: 11));

      expect(tracker.findPrunableRoots(), equals(["root"]));
    });
  });
}

class _FakeClock({required DateTime initial}) {
  DateTime _current = initial;

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
    approvalOverride: null,
    autoContinuation: null,
    branchName: null,
    id: id,
    pluginId: "fake",
    projectID: projectID,
    directory: directory,
    parentID: parentID,
    title: title,
    time: null,
    promptDefaults: null,
    lastUserActivityAt: null,
  );
}

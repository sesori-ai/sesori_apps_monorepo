import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_bridge/src/push/push_notification_service.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PushNotificationService", () {
    test("AC1a: SesoriMessageUpdated with user role sends no notification", () {
      final harness = _newHarness();

      harness.service.handleSseEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(id: "msg-1", role: "user", sessionID: "session-a", agent: null, modelID: null, providerID: null),
        ),
      );

      expect(harness.client.sentPayloads, isEmpty);
    });

    test("AC1b: SesoriMessageUpdated with assistant role sends no notification", () {
      final harness = _newHarness();

      harness.service.handleSseEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(id: "msg-1", role: "assistant", sessionID: "session-a", agent: null, modelID: null, providerID: null),
        ),
      );

      expect(harness.client.sentPayloads, isEmpty);
    });

    test("AC2: parent+child idle completion sends one agentTurnCompleted notification", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "parent", title: "Parent title"),
          ),
        );
        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "parent"),
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "parent", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.client.sentPayloads, isEmpty);

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "parent", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.client.sentPayloads.length, equals(1));
        final payload = harness.client.sentPayloads.single;
        expect(payload.category, equals(NotificationCategory.sessionMessage));
        expect(payload.data?.eventType, equals(NotificationEventType.agentTurnCompleted));
      });
    });

    test("AC3a: question asked during debounce cancels completion", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.service.handleSseEvent(
          const SesoriSseEvent.questionAsked(
            id: "q-1",
            sessionID: "session-a",
            questions: [QuestionInfo(header: "Prompt", question: "Continue?")],
          ),
        );

        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();
        final completionCount = harness.client.sentPayloads
            .where((payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted)
            .length;
        expect(completionCount, equals(0));
      });
    });

    test("AC3b: permission asked during debounce cancels completion", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.service.handleSseEvent(
          const SesoriSseEvent.permissionAsked(
            requestID: "perm-1",
            sessionID: "session-a",
            tool: "bash",
            description: "Run command",
          ),
        );

        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();
        final completionCount = harness.client.sentPayloads
            .where((payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted)
            .length;
        expect(completionCount, equals(0));
      });
    });

    test("AC4: completion uses session title and assistant text preview", () {
      fakeAsync((async) {
        final harness = _newHarness();
        const title = "Implement user authentication for the dashboard";

        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "session-a", title: title),
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(id: "msg-1", role: "assistant", sessionID: "session-a", agent: null, modelID: null, providerID: null),
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.messagePartUpdated(
            part: MessagePart(
              id: "part-1",
              sessionID: "session-a",
              messageID: "msg-1",
              type: MessagePartType.text,
              text: "I implemented user auth using JWT, refresh tokens, secure cookies, and role checks.",
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

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completion = harness.client.sentPayloads.singleWhere(
          (payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted,
        );
        expect(completion.title, equals(title));
        expect(completion.body, equals("I implemented user auth using JWT, refresh tokens, secure cookies,..."));
      });
    });

    test("AC5: debounce fires only after full 500ms", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();
        expect(harness.client.sentPayloads, isEmpty);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(harness.client.sentPayloads.length, equals(1));
      });
    });

    test("AC6: parent idle with busy child waits for child idle", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(SesoriSseEvent.sessionCreated(info: _session(id: "parent")));
        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "parent"),
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "parent", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "parent", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.client.sentPayloads, isEmpty);

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.client.sentPayloads.length, equals(1));
        expect(
          harness.client.sentPayloads.single.data?.eventType,
          equals(NotificationEventType.agentTurnCompleted),
        );
      });
    });

    test("AC7: reset clears state and cancels pending debounce timers", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(SesoriSseEvent.sessionCreated(info: _session(id: "session-a")));
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        harness.service.reset();

        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        expect(harness.client.sentPayloads, isEmpty);
      });
    });

    test("AC8: question replied cancels pending completion", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        harness.service.handleSseEvent(
          const SesoriSseEvent.questionAsked(
            id: "q-1",
            sessionID: "session-a",
            questions: [QuestionInfo(header: "Prompt", question: "Proceed?")],
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.questionReplied(requestID: "q-1", sessionID: "session-a"),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completionCount = harness.client.sentPayloads
            .where((payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted)
            .length;
        expect(completionCount, equals(0));
      });
    });

    test("AC9a: question asked still sends immediate aiInteraction notification", () {
      final harness = _newHarness();

      harness.service.handleSseEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "session-a",
          questions: [QuestionInfo(header: "Prompt", question: "Continue?")],
        ),
      );

      expect(harness.client.sentPayloads.length, equals(1));
      final payload = harness.client.sentPayloads.single;
      expect(payload.category, equals(NotificationCategory.aiInteraction));
      expect(payload.data?.eventType, equals(NotificationEventType.questionAsked));
    });

    test("AC9b: installation update still sends immediate systemUpdate notification", () {
      final harness = _newHarness();

      harness.service.handleSseEvent(
        const SesoriSseEvent.installationUpdateAvailable(version: "1.2.3"),
      );

      expect(harness.client.sentPayloads.length, equals(1));
      final payload = harness.client.sentPayloads.single;
      expect(payload.category, equals(NotificationCategory.systemUpdate));
      expect(
        payload.data?.eventType,
        equals(NotificationEventType.installationUpdateAvailable),
      );
    });

    test("AC10a: tool message part does not affect completion body", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(id: "msg-1", role: "assistant", sessionID: "session-a", agent: null, modelID: null, providerID: null),
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.messagePartUpdated(
            part: MessagePart(
              id: "part-1",
              sessionID: "session-a",
              messageID: "msg-1",
              type: MessagePartType.tool,
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
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completion = harness.client.sentPayloads.singleWhere(
          (payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted,
        );
        expect(completion.body, equals("Task completed"));
      });
    });

    test("AC10b: text message part updates completion body", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(id: "msg-1", role: "assistant", sessionID: "session-a", agent: null, modelID: null, providerID: null),
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.messagePartUpdated(
            part: MessagePart(
              id: "part-1",
              sessionID: "session-a",
              messageID: "msg-1",
              type: MessagePartType.text,
              text: "Done with migration, tests, docs, and verification checks.",
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
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completion = harness.client.sentPayloads.singleWhere(
          (payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted,
        );
        expect(completion.body, equals("Done with migration, tests, docs, and verification checks."));
      });
    });

    test("E1: session deleted during debounce cancels completion timer", () {
      fakeAsync((async) {
        final harness = _newHarness();

        final session = _session(id: "session-a");
        harness.service.handleSseEvent(SesoriSseEvent.sessionCreated(info: session));
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.service.handleSseEvent(SesoriSseEvent.sessionDeleted(info: session));

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(harness.client.sentPayloads, isEmpty);
      });
    });

    test("E2: busy-idle-busy-idle only yields one completion notification", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completionCount = harness.client.sentPayloads
            .where((payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted)
            .length;
        expect(completionCount, equals(1));
      });
    });

    test("E3: multiple children finishing in sequence produces a single completion", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child-1", parentID: "root"),
          ),
        );
        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child-2", parentID: "root"),
          ),
        );

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child-1", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child-2", status: SessionStatus.busy()),
        );

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child-1", status: SessionStatus.idle()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.client.sentPayloads, isEmpty);

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child-2", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completionCount = harness.client.sentPayloads
            .where((payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted)
            .length;
        expect(completionCount, equals(1));
      });
    });

    test("E4: completion body falls back when no assistant text exists", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completion = harness.client.sentPayloads.singleWhere(
          (payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted,
        );
        expect(completion.body, equals("Task completed"));
      });
    });

    test("E5: completion title falls back when session title is null", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(info: _session(id: "session-a", title: null)),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completion = harness.client.sentPayloads.singleWhere(
          (payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted,
        );
        expect(completion.title, equals("Session completed"));
      });
    });

    test("E8: duplicate idle without new busy does not send duplicate completion", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        expect(harness.client.sentPayloads.length, equals(1));

        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completionCount = harness.client.sentPayloads
            .where((payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted)
            .length;
        expect(completionCount, equals(1));
      });
    });

    test("AC11: completion notification includes projectId from tracker", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "session-a", projectID: "project-x"),
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        final completion = harness.client.sentPayloads.singleWhere(
          (payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted,
        );
        expect(completion.data?.projectId, equals("project-x"));
      });
    });

    test("AC12: question notification includes projectId from tracker", () {
      final harness = _newHarness();

      harness.service.handleSseEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "session-a", projectID: "project-y"),
        ),
      );
      harness.service.handleSseEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "session-a",
          questions: [QuestionInfo(header: "h", question: "q")],
        ),
      );

      expect(harness.client.sentPayloads.length, equals(1));
      expect(harness.client.sentPayloads.single.data?.projectId, equals("project-y"));
    });

    test("E9a: projects summary redirects child completion to root after restart", () {
      fakeAsync((async) {
        final harness = _newHarness();

        // Simulate bridge restart: only status events, no sessionCreated.
        harness.service.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "root", title: "Root task"),
          ),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );
        harness.service.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );

        // projects.summary establishes the parent link during debounce.
        harness.service.handleSseEvent(
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

        // Wait for debounce + re-resolve debounce.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Should get exactly one completion notification for the root, not the child.
        final completions = harness.client.sentPayloads
            .where((p) => p.data?.eventType == NotificationEventType.agentTurnCompleted)
            .toList();
        expect(completions.length, equals(1));
        expect(completions.single.title, equals("Root task"));
      });
    });

    test("E9: question asked for untracked session still sends aiInteraction", () {
      final harness = _newHarness();

      harness.service.handleSseEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "missing-session",
          questions: [QuestionInfo(header: "Prompt", question: "Need decision")],
        ),
      );

      expect(harness.client.sentPayloads.length, equals(1));
      expect(harness.client.sentPayloads.single.category, equals(NotificationCategory.aiInteraction));
    });
  });

  group("truncate helpers", () {
    test("truncateTitle truncates at word boundary with ellipsis", () {
      const title = "One two three four five six seven eight nine ten eleven twelve";
      expect(truncateTitle(title, maxChars: 25), equals("One two three four five..."));
    });

    test("truncateToWords truncates to max word count with ellipsis", () {
      const text = "one two three four five six seven eight nine ten eleven";
      expect(truncateToWords(text, maxWords: 10), equals("one two three four five six seven eight nine ten..."));
    });
  });
}

({
  PushNotificationService service,
  FakePushNotificationClient client,
})
_newHarness() {
  final client = FakePushNotificationClient();
  final tracker = PushSessionStateTracker();
  final notifier = CompletionNotifier(
    tracker: tracker,
    debounceDuration: const Duration(milliseconds: 500),
  );
  final service = PushNotificationService(
    client: client,
    rateLimiter: FakePushRateLimiter(),
    tracker: tracker,
    completionNotifier: notifier,
  );

  return (service: service, client: client);
}

class FakePushNotificationClient extends PushNotificationClient {
  final List<SendNotificationPayload> sentPayloads = [];

  FakePushNotificationClient()
    : super(
        authBackendURL: "https://example.com",
        tokenRefreshManager: _FakeTokenRefresher(),
      );

  @override
  Future<void> sendNotification(SendNotificationPayload payload) async {
    sentPayloads.add(payload);
  }
}

class FakePushRateLimiter extends PushRateLimiter {
  FakePushRateLimiter();

  @override
  bool shouldSend({
    required NotificationCategory category,
    required String? sessionId,
    required String collapseKey,
  }) {
    return true;
  }
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    return "token";
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
  );
}

import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/completion_push_listener.dart";
import "package:sesori_bridge/src/push/push_dispatcher.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart";
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_bridge/src/push/push_notification_content_builder.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker_models.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PushDispatcher", () {
    test("AC1a: SesoriMessageUpdated with user role sends no notification", () {
      final harness = _newHarness();

      harness.dispatcher.handleSseEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "msg-1",
            role: "user",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );

      expect(harness.client.sentPayloads, isEmpty);
    });

    test("AC6a: SesoriQuestionAsked sends questionAsked notification", () {
      final harness = _newHarness();

      harness.dispatcher.handleSseEvent(
        const SesoriSseEvent.questionAsked(
          id: "q-1",
          sessionID: "session-a",
          questions: [QuestionInfo(header: "Prompt", question: "Continue?")],
        ),
      );

      expect(harness.client.sentPayloads, hasLength(1));
      final payload = harness.client.sentPayloads.single;
      expect(payload.category, equals(NotificationCategory.aiInteraction));
      expect(payload.data?.eventType, equals(NotificationEventType.questionAsked));
    });

    test("completion dispatch uses session title and assistant text preview", () {
      final harness = _newHarness();
      const title = "Implement user authentication for the dashboard";

      harness.dispatcher.handleSseEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "session-a", title: title),
        ),
      );
      harness.dispatcher.handleSseEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "msg-1",
            role: "assistant",
            sessionID: "session-a",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );
      harness.dispatcher.handleSseEvent(
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

      harness.dispatcher.dispatchCompletionForRoot(rootSessionId: "session-a");

      final completion = harness.client.sentPayloads.singleWhere(
        (payload) => payload.data?.eventType == NotificationEventType.agentTurnCompleted,
      );
      expect(completion.title, equals(title));
      expect(completion.body, equals("I implemented user auth using JWT, refresh tokens, secure cookies,..."));
      expect(harness.tracker.getLatestAssistantText("session-a"), isNull);
    });

    test("completion clears root subtree assistant text before rate-limit gating", () {
      final harness = _newHarness(
        rateLimiter: FakePushRateLimiter(shouldAllowSend: false),
      );

      harness.dispatcher.handleSseEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "root", title: "Root task"),
        ),
      );
      harness.dispatcher.handleSseEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );
      harness.dispatcher.handleSseEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message(
            id: "msg-1",
            role: "assistant",
            sessionID: "child",
            agent: null,
            modelID: null,
            providerID: null,
          ),
        ),
      );
      harness.dispatcher.handleSseEvent(
        const SesoriSseEvent.messagePartUpdated(
          part: MessagePart(
            id: "part-1",
            sessionID: "child",
            messageID: "msg-1",
            type: MessagePartType.text,
            text: "Child preview survives payload derivation but should be cleared after.",
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

      harness.dispatcher.dispatchCompletionForRoot(rootSessionId: "root");

      expect(harness.client.sentPayloads, isEmpty);
      expect(harness.tracker.getLatestAssistantText("root"), isNull);
      expect(harness.tracker.getLatestAssistantText("child"), isNull);
    });

    test("markSessionAborted delegates abort suppression to the notifier", () {
      final harness = _newHarness();

      harness.dispatcher.handleSseEvent(
        SesoriSseEvent.sessionCreated(info: _session(id: "root")),
      );
      harness.dispatcher.handleSseEvent(
        SesoriSseEvent.sessionCreated(
          info: _session(id: "child", parentID: "root"),
        ),
      );

      harness.dispatcher.markSessionAborted("child");

      expect(harness.notifier.abortedRootCount, equals(1));
    });

    test("AC2: parent+child idle completion sends one agentTurnCompleted notification", () {
      fakeAsync((async) {
        final harness = _newHarness();
        harness.completionListener.start();

        harness.dispatcher.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "root", title: "Root task title"),
          ),
        );
        harness.dispatcher.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "root"),
          ),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(
              id: "msg-1",
              role: "assistant",
              sessionID: "child",
              agent: null,
              modelID: null,
              providerID: null,
            ),
          ),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.messagePartUpdated(
            part: MessagePart(
              id: "part-1",
              sessionID: "child",
              messageID: "msg-1",
              type: MessagePartType.text,
              text: "Finished the child work and rolled the result up to the parent.",
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
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.client.sentPayloads, hasLength(1));
        final payload = harness.client.sentPayloads.single;
        expect(payload.category, equals(NotificationCategory.sessionMessage));
        expect(payload.data?.eventType, equals(NotificationEventType.agentTurnCompleted));
        expect(payload.data?.sessionId, equals("root"));
        expect(payload.data?.projectId, equals("project-a"));
      });
    });

    test("abort suppression keeps the next completion notification from dispatching", () {
      fakeAsync((async) {
        final harness = _newHarness();
        harness.completionListener.start();

        harness.dispatcher.handleSseEvent(
          SesoriSseEvent.sessionCreated(info: _session(id: "root")),
        );
        harness.dispatcher.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "root"),
          ),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );

        harness.dispatcher.markSessionAborted("child");

        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        expect(harness.client.sentPayloads, isEmpty);
        expect(harness.notifier.abortedRootCount, equals(1));
      });
    });

    test("seeded projects summary redirects completion payloads to the real root", () {
      fakeAsync((async) {
        final harness = _newHarness();
        harness.completionListener.start();

        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.projectsSummary(
            projects: [
              ProjectActivitySummary(
                id: "project-from-summary",
                activeSessions: [
                  ActiveSession(
                    id: "root",
                    mainAgentRunning: false,
                    childSessionIds: ["child"],
                  ),
                ],
              ),
            ],
          ),
        );
        harness.dispatcher.handleSseEvent(
          SesoriSseEvent.sessionUpdated(
            info: _session(id: "root", projectID: "project-from-summary", title: "Seeded root"),
          ),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.messageUpdated(
            info: Message(
              id: "msg-1",
              role: "assistant",
              sessionID: "child",
              agent: null,
              modelID: null,
              providerID: null,
            ),
          ),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.messagePartUpdated(
            part: MessagePart(
              id: "part-1",
              sessionID: "child",
              messageID: "msg-1",
              type: MessagePartType.text,
              text: "Summary-seeded child completion should still notify as the root session.",
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
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        expect(harness.client.sentPayloads, isEmpty);

        async.elapse(const Duration(milliseconds: 800));
        async.flushMicrotasks();

        expect(harness.client.sentPayloads, hasLength(1));
        final payload = harness.client.sentPayloads.single;
        expect(payload.data?.eventType, equals(NotificationEventType.agentTurnCompleted));
        expect(payload.data?.sessionId, equals("root"));
        expect(payload.data?.projectId, equals("project-from-summary"));
      });
    });

    test("M2: prunable roots trigger tracker prune, notifier cleanup, and rate-limiter stale cleanup", () {
      fakeAsync((async) {
        final harness = _newHarness(
          now: () => DateTime(2026, 4, 16).add(async.elapsed),
        );

        harness.dispatcher.handleSseEvent(SesoriSseEvent.sessionCreated(info: _session(id: "root")));
        harness.dispatcher.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "child", parentID: "root"),
          ),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "child", status: SessionStatus.idle()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        harness.dispatcher.markSessionAborted("child");

        expect(harness.notifier.completionSentRootCount, equals(1));

        async.elapse(const Duration(minutes: 40));
        async.flushMicrotasks();
        harness.dispatcher.runMaintenancePass();

        final telemetry = harness.dispatcher.lastMaintenanceTelemetry;
        expect(telemetry, isNotNull);
        expect(telemetry!.sessions, equals(0));
        expect(telemetry.prunableRoots, equals(0));
        expect(telemetry.completionSentRoots, equals(0));
        expect(telemetry.abortedRoots, equals(0));
        expect(telemetry.rateLimiterKeys, equals(0));
      });
    });

    test("M3: post-maintenance telemetry snapshot reflects maintained state", () {
      fakeAsync((async) {
        final harness = _newHarness(
          now: () => DateTime(2026, 4, 16).add(async.elapsed),
        );

        harness.dispatcher.handleSseEvent(
          SesoriSseEvent.sessionCreated(info: _session(id: "root")),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "root", status: SessionStatus.idle()),
        );

        async.elapse(const Duration(minutes: 40));
        async.flushMicrotasks();
        harness.dispatcher.runMaintenancePass();

        final telemetry = harness.dispatcher.lastMaintenanceTelemetry;
        expect(telemetry, isNotNull);
        expect(telemetry!.sessions, equals(0));
        expect(telemetry.idleRoots, equals(0));
        expect(telemetry.prunableRoots, equals(0));
        expect(telemetry.completionSentRoots, equals(0));
        expect(telemetry.abortedRoots, equals(0));
      });
    });

    test("maintenance logs telemetry snapshots", () {
      final harness = _newHarness();

      final stdout = _captureStdout(
        level: LogLevel.debug,
        action: harness.dispatcher.runMaintenancePass,
      );

      expect(harness.dispatcher.lastMaintenanceTelemetry, isNotNull);
      expect(stdout, contains(harness.dispatcher.lastMaintenanceTelemetry!.toLogMessage()));
    });

    test("M3b: maintenance continues when root pruning throws", () {
      final tracker = ThrowingPushSessionStateTracker(
        now: DateTime.now,
        throwFindPrunableRoots: true,
      );
      final harness = _newHarness(
        tracker: tracker,
        rssBytesReader: () => 3 * 1024 * 1024,
      );

      harness.rateLimiter.shouldSend(
        category: NotificationCategory.sessionMessage,
        sessionId: "session-a",
        collapseKey: "sessionMessage-session-a",
      );

      harness.dispatcher.runMaintenancePass();

      final telemetry = harness.dispatcher.lastMaintenanceTelemetry;
      expect(telemetry, isNotNull);
      expect(telemetry!.rssMb, closeTo(3, 0.001));
      expect(telemetry.rateLimiterKeys, equals(1));
    });

    test("reset clears tracker and notifier state", () {
      fakeAsync((async) {
        final harness = _newHarness();

        harness.dispatcher.handleSseEvent(
          SesoriSseEvent.sessionCreated(
            info: _session(id: "session-a", title: "Session A"),
          ),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.busy()),
        );
        harness.dispatcher.handleSseEvent(
          const SesoriSseEvent.sessionStatus(sessionID: "session-a", status: SessionStatus.idle()),
        );
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();
        harness.dispatcher.markSessionAborted("session-a");

        harness.dispatcher.reset();

        expect(harness.tracker.getSessionTitle("session-a"), isNull);
        expect(harness.notifier.completionSentRootCount, equals(0));
        expect(harness.notifier.abortedRootCount, equals(0));
      });
    });

    test("dispose closes the notifier completion stream", () async {
      final harness = _newHarness();
      final done = expectLater(harness.notifier.completions, emitsDone);

      await harness.dispatcher.dispose();

      await done;
    });
  });
}

({
  PushDispatcher dispatcher,
  FakePushNotificationClient client,
  PushSessionStateTracker tracker,
  CompletionNotifier notifier,
  CompletionPushListener completionListener,
  FakePushRateLimiter rateLimiter,
})
_newHarness({
  FakePushNotificationClient? client,
  FakePushRateLimiter? rateLimiter,
  PushSessionStateTracker? tracker,
  DateTime Function()? now,
  int? Function()? rssBytesReader,
}) {
  final resolvedClient = client ?? FakePushNotificationClient();
  final resolvedTracker = tracker ?? PushSessionStateTracker(now: now ?? DateTime.now);
  final notifier = CompletionNotifier(
    tracker: resolvedTracker,
    debounceDuration: const Duration(milliseconds: 500),
  );
  final resolvedRateLimiter = rateLimiter ?? FakePushRateLimiter(now: now);
  final resolvedRssBytesReader = rssBytesReader ?? readCurrentRssBytes;
  final telemetryBuilder = PushMaintenanceTelemetryBuilder(
    completionNotifier: notifier,
    rateLimiter: resolvedRateLimiter,
    rssBytesReader: resolvedRssBytesReader,
  );
  const contentBuilder = PushNotificationContentBuilder();
  final dispatcher = PushDispatcher(
    client: resolvedClient,
    rateLimiter: resolvedRateLimiter,
    tracker: resolvedTracker,
    completionNotifier: notifier,
    telemetryBuilder: telemetryBuilder,
    contentBuilder: contentBuilder,
  );
  final completionListener = CompletionPushListener(
    completionNotifier: notifier,
    dispatcher: dispatcher,
  );

  return (
    dispatcher: dispatcher,
    client: resolvedClient,
    tracker: resolvedTracker,
    notifier: notifier,
    completionListener: completionListener,
    rateLimiter: resolvedRateLimiter,
  );
}

class ThrowingPushSessionStateTracker extends PushSessionStateTracker {
  final bool throwFindPrunableRoots;

  ThrowingPushSessionStateTracker({required super.now, this.throwFindPrunableRoots = false});

  @override
  List<PushPrunableRoot> findPrunableRoots() {
    if (throwFindPrunableRoots) {
      throw StateError("findPrunableRoots boom");
    }

    return super.findPrunableRoots();
  }
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
  bool shouldAllowSend;

  FakePushRateLimiter({this.shouldAllowSend = true, super.now});

  @override
  bool shouldSend({
    required NotificationCategory category,
    required String? sessionId,
    required String collapseKey,
  }) {
    if (!shouldAllowSend) {
      return false;
    }

    return super.shouldSend(
      category: category,
      sessionId: sessionId,
      collapseKey: collapseKey,
    );
  }
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    return "token";
  }
}

class _BufferingStdout implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void write(Object? object) {
    _buffer.write(object);
  }

  @override
  void writeln([Object? object = ""]) {
    _buffer.writeln(object);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

String _captureStdout({required LogLevel level, required void Function() action}) {
  final stdoutBuffer = _BufferingStdout();
  final stderrBuffer = _BufferingStdout();
  final previousLevel = Log.level;
  try {
    Log.level = level;
    IOOverrides.runZoned(
      action,
      stdout: () => stdoutBuffer,
      stderr: () => stderrBuffer,
    );
  } finally {
    Log.level = previousLevel;
  }

  return stdoutBuffer.text;
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

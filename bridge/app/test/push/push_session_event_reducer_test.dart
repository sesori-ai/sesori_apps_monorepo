import "package:sesori_bridge/src/push/push_session_event_reducer.dart";
import "package:sesori_bridge/src/push/push_session_state_mutator.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PushSessionEventReducer", () {
    test("sessionCreated: upserts tracked session metadata", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);
      final session = _session(
        id: "session-a",
        parentID: "parent",
        projectID: "project-b",
        title: "Write tests",
      );
      harness.sessions["parent"] = _trackedSessionState();

      harness.handle(
        event: SesoriSseEvent.sessionCreated(info: session),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"];
      expect(trackedSession, isNotNull);
      expect(trackedSession!.parentId, equals("parent"));
      expect(trackedSession.projectId, equals("project-b"));
      expect(trackedSession.title, equals("Write tests"));
      expect(trackedSession.lastTouchedAt, equals(now));
      expect(harness.sessions["parent"]!.childIds, contains("session-a"));
      expect(harness.mutator.upsertCalls, hasLength(1));
      expect(harness.mutator.upsertCalls.single.session, same(session));
      expect(harness.mutator.upsertCalls.single.touchedAt, equals(now));
    });

    test("sessionUpdated: reassigns parent links and refreshes session fields", () {
      final harness = _ReducerHarness();
      final before = DateTime.utc(2026, 1, 1, 11);
      final now = DateTime.utc(2026, 1, 1, 12);
      final updatedSession = _session(
        id: "child",
        parentID: "new-parent",
        projectID: "project-new",
        title: "Updated title",
      );

      harness.sessions["old-parent"] = _trackedSessionState(childIds: <String>{"child"});
      harness.sessions["new-parent"] = _trackedSessionState();
      harness.sessions["child"] = _trackedSessionState(
        parentId: "old-parent",
        projectId: "project-old",
        title: "Original title",
        lastTouchedAt: before,
      );

      harness.handle(
        event: SesoriSseEvent.sessionUpdated(info: updatedSession),
        now: now,
      );

      final trackedSession = harness.sessions["child"]!;
      expect(trackedSession.parentId, equals("new-parent"));
      expect(trackedSession.projectId, equals("project-new"));
      expect(trackedSession.title, equals("Updated title"));
      expect(trackedSession.lastTouchedAt, equals(now));
      expect(harness.sessions["old-parent"]!.childIds, isNot(contains("child")));
      expect(harness.sessions["new-parent"]!.childIds, contains("child"));
      expect(harness.mutator.upsertCalls, hasLength(1));
      expect(harness.mutator.upsertCalls.single.session, same(updatedSession));
    });

    test("sessionDeleted: removes tracked state, child links, and indexed metadata", () {
      final harness = _ReducerHarness();
      final before = DateTime.utc(2026, 1, 1, 11);

      harness.sessions["parent"] = _trackedSessionState(childIds: <String>{"deleted"});
      harness.sessions["deleted"] = _trackedSessionState(
        parentId: "parent",
        childIds: <String>{"grandchild"},
        messageIds: <String>{"message-1", "message-2"},
      );
      harness.sessions["grandchild"] = _trackedSessionState(parentId: "deleted");
      harness.sessions["other"] = _trackedSessionState(messageIds: <String>{"keep"});
      harness.messageRoles["message-1"] = _trackedMessageRole(
        role: "assistant",
        sessionId: "deleted",
        updatedAt: before,
      );
      harness.messageRoles["message-2"] = _trackedMessageRole(
        role: "user",
        sessionId: "deleted",
        updatedAt: before,
      );
      harness.messageRoles["keep"] = _trackedMessageRole(
        role: "assistant",
        sessionId: "other",
        updatedAt: before,
      );
      harness.permissionRequestToSession["perm-deleted"] = "deleted";
      harness.permissionRequestToSession["perm-other"] = "other";

      harness.handle(
        event: SesoriSseEvent.sessionDeleted(info: _session(id: "deleted")),
        now: DateTime.utc(2026, 1, 1, 12),
      );

      expect(harness.sessions.containsKey("deleted"), isFalse);
      expect(harness.sessions["parent"]!.childIds, isNot(contains("deleted")));
      expect(harness.sessions["grandchild"]!.parentId, isNull);
      expect(harness.messageRoles.containsKey("message-1"), isFalse);
      expect(harness.messageRoles.containsKey("message-2"), isFalse);
      expect(harness.messageRoles.containsKey("keep"), isTrue);
      expect(harness.permissionRequestToSession.containsKey("perm-deleted"), isFalse);
      expect(harness.permissionRequestToSession["perm-other"], equals("other"));
      expect(harness.mutator.deletedSessionIds, equals(<String>["deleted"]));
    });

    test("sessionStatus busy: creates a session and marks it previously busy", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);

      harness.handle(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.busy(),
        ),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"];
      expect(trackedSession, isNotNull);
      expect(trackedSession!.status, equals(const SessionStatus.busy()));
      expect(trackedSession.previouslyBusy, isTrue);
      expect(trackedSession.lastTouchedAt, equals(now));
    });

    test("sessionStatus retry: stores retry status and marks the session previously busy", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);
      const status = SessionStatus.retry(
        attempt: 2,
        message: "retrying",
        next: 1000,
      );

      harness.handle(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: status,
        ),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"];
      expect(trackedSession, isNotNull);
      expect(trackedSession!.status, equals(status));
      expect(trackedSession.previouslyBusy, isTrue);
      expect(trackedSession.lastTouchedAt, equals(now));
    });

    test("sessionStatus idle: clears the active status and refreshes the timestamp", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);

      harness.sessions["session-a"] = _trackedSessionState(
        status: const SessionStatus.busy(),
        previouslyBusy: true,
        lastTouchedAt: DateTime.utc(2026, 1, 1, 11),
      );

      harness.handle(
        event: const SesoriSseEvent.sessionStatus(
          sessionID: "session-a",
          status: SessionStatus.idle(),
        ),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"]!;
      expect(trackedSession.status, isNull);
      expect(trackedSession.previouslyBusy, isTrue);
      expect(trackedSession.lastTouchedAt, equals(now));
    });

    test("messageUpdated: tracks message role metadata and indexes the message on the session", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);
      final message = _message(
        id: "message-1",
        role: "assistant",
        sessionID: "session-a",
      );

      harness.handle(
        event: SesoriSseEvent.messageUpdated(info: message),
        now: now,
      );

      final role = harness.messageRoles["message-1"];
      final trackedSession = harness.sessions["session-a"];
      expect(role, isNotNull);
      expect(role!.role, equals("assistant"));
      expect(role.sessionId, equals("session-a"));
      expect(role.updatedAt, equals(now));
      expect(trackedSession, isNotNull);
      expect(trackedSession!.messageIds, contains("message-1"));
      expect(trackedSession.lastTouchedAt, equals(now));
      expect(harness.mutator.trackMessageCalls, hasLength(1));
      expect(harness.mutator.trackMessageCalls.single.sessionId, equals("session-a"));
      expect(harness.mutator.trackMessageCalls.single.messageId, equals("message-1"));
      expect(harness.mutator.trackMessageCalls.single.touchedAt, equals(now));
    });

    test("messageRemoved: untracks the indexed message and refreshes the owning session", () {
      final harness = _ReducerHarness();
      final before = DateTime.utc(2026, 1, 1, 11);
      final now = DateTime.utc(2026, 1, 1, 12);

      harness.sessions["owner-session"] = _trackedSessionState(
        messageIds: <String>{"message-1"},
        lastTouchedAt: before,
      );
      harness.messageRoles["message-1"] = _trackedMessageRole(
        role: "assistant",
        sessionId: "owner-session",
        updatedAt: before,
      );

      harness.handle(
        event: const SesoriSseEvent.messageRemoved(
          sessionID: "payload-session",
          messageID: "message-1",
        ),
        now: now,
      );

      expect(harness.messageRoles.containsKey("message-1"), isFalse);
      expect(harness.sessions["owner-session"]!.messageIds, isEmpty);
      expect(harness.sessions["owner-session"]!.lastTouchedAt, equals(now));
      expect(harness.mutator.untrackMessageIds, equals(<String>["message-1"]));
    });

    test("messagePartUpdated: refreshes assistant text and message role timestamps", () {
      final harness = _ReducerHarness();
      final before = DateTime.utc(2026, 1, 1, 11);
      final now = DateTime.utc(2026, 1, 1, 12);
      final part = _textPart(
        sessionID: "session-a",
        messageID: "message-1",
        text: "Tests are green",
      );

      harness.messageRoles["message-1"] = _trackedMessageRole(
        role: "assistant",
        sessionId: "session-a",
        updatedAt: before,
      );

      harness.handle(
        event: SesoriSseEvent.messagePartUpdated(part: part),
        now: now,
      );

      final role = harness.messageRoles["message-1"];
      final trackedSession = harness.sessions["session-a"];
      expect(role, isNotNull);
      expect(role!.role, equals("assistant"));
      expect(role.sessionId, equals("session-a"));
      expect(role.updatedAt, equals(now));
      expect(trackedSession, isNotNull);
      expect(trackedSession!.latestAssistantText, equals("Tests are green"));
      expect(trackedSession.lastTouchedAt, equals(now));
      expect(harness.mutator.updateLatestAssistantTextParts, equals(<MessagePart>[part]));
    });

    test("messagePartUpdated nonAssistant: does not overwrite assistant preview text", () {
      final harness = _ReducerHarness();
      final before = DateTime.utc(2026, 1, 1, 11);
      final now = DateTime.utc(2026, 1, 1, 12);
      final part = _textPart(
        sessionID: "session-a",
        messageID: "message-1",
        text: "User text should not replace the preview",
      );

      harness.sessions["session-a"] = _trackedSessionState(
        latestAssistantText: "Existing preview",
      );
      harness.messageRoles["message-1"] = _trackedMessageRole(
        role: "user",
        sessionId: "session-a",
        updatedAt: before,
      );

      harness.handle(
        event: SesoriSseEvent.messagePartUpdated(part: part),
        now: now,
      );

      expect(harness.sessions["session-a"]!.latestAssistantText, equals("Existing preview"));
      expect(harness.messageRoles["message-1"]!.updatedAt, equals(now));
      expect(harness.sessions["session-a"]!.lastTouchedAt, equals(now));
      expect(harness.mutator.updateLatestAssistantTextParts, equals(<MessagePart>[part]));
    });

    test("questionAsked: marks the session as pending a question response", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);

      harness.handle(
        event: const SesoriSseEvent.questionAsked(
          id: "question-1",
          sessionID: "session-a",
          questions: <QuestionInfo>[
            QuestionInfo(header: "Prompt", question: "Continue?"),
          ],
        ),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"];
      expect(trackedSession, isNotNull);
      expect(trackedSession!.hasPendingQuestion, isTrue);
      expect(trackedSession.lastTouchedAt, equals(now));
    });

    test("questionReplied: clears pending question state without touching permission state", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);

      harness.sessions["session-a"] = _trackedSessionState(
        hasPendingQuestion: true,
        hasPendingPermission: true,
      );

      harness.handle(
        event: const SesoriSseEvent.questionReplied(
          requestID: "question-1",
          sessionID: "session-a",
        ),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"]!;
      expect(trackedSession.hasPendingQuestion, isFalse);
      expect(trackedSession.hasPendingPermission, isTrue);
      expect(trackedSession.lastTouchedAt, equals(now));
    });

    test("questionRejected: clears pending question state on the tracked session", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);

      harness.sessions["session-a"] = _trackedSessionState(hasPendingQuestion: true);

      harness.handle(
        event: const SesoriSseEvent.questionRejected(
          requestID: "question-1",
          sessionID: "session-a",
        ),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"]!;
      expect(trackedSession.hasPendingQuestion, isFalse);
      expect(trackedSession.lastTouchedAt, equals(now));
    });

    test("permissionAsked: stores the request mapping and marks the session pending permission", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);

      harness.handle(
        event: const SesoriSseEvent.permissionAsked(
          requestID: "perm-1",
          sessionID: "session-a",
          tool: "bash",
          description: "Run tests",
        ),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"];
      expect(harness.permissionRequestToSession["perm-1"], equals("session-a"));
      expect(trackedSession, isNotNull);
      expect(trackedSession!.hasPendingPermission, isTrue);
      expect(trackedSession.lastTouchedAt, equals(now));
    });

    test("permissionReplied: clears pending permission using the stored request mapping", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);

      harness.sessions["session-a"] = _trackedSessionState(hasPendingPermission: true);
      harness.permissionRequestToSession["perm-1"] = "session-a";

      harness.handle(
        event: const SesoriSseEvent.permissionReplied(
          requestID: "perm-1",
          sessionID: "different-session",
          reply: "allow",
        ),
        now: now,
      );

      final trackedSession = harness.sessions["session-a"]!;
      expect(harness.permissionRequestToSession.containsKey("perm-1"), isFalse);
      expect(trackedSession.hasPendingPermission, isFalse);
      expect(trackedSession.lastTouchedAt, equals(now));
    });

    test("projectsSummary: delegates project-child links and project ids to the mutator", () {
      final harness = _ReducerHarness();
      final now = DateTime.utc(2026, 1, 1, 12);
      final projects = <ProjectActivitySummary>[
        const ProjectActivitySummary(
          id: "project-a",
          activeSessions: <ActiveSession>[
            ActiveSession(
              id: "root",
              mainAgentRunning: false,
              childSessionIds: <String>["child"],
            ),
          ],
        ),
      ];

      harness.handle(
        event: SesoriSseEvent.projectsSummary(projects: projects),
        now: now,
      );

      final root = harness.sessions["root"];
      final child = harness.sessions["child"];
      expect(root, isNotNull);
      expect(child, isNotNull);
      expect(root!.projectId, equals("project-a"));
      expect(root.childIds, contains("child"));
      expect(root.lastTouchedAt, equals(now));
      expect(child!.projectId, equals("project-a"));
      expect(child.parentId, equals("root"));
      expect(child.lastTouchedAt, equals(now));
      expect(harness.mutator.applyProjectsSummaryCalls, hasLength(1));
      expect(harness.mutator.applyProjectsSummaryCalls.single.projects, equals(projects));
      expect(harness.mutator.applyProjectsSummaryCalls.single.touchedAt, equals(now));
    });
  });
}

class _ReducerHarness {
  final Map<String, PushTrackedSessionState> sessions = <String, PushTrackedSessionState>{};
  final Map<String, PushTrackedMessageRole> messageRoles = <String, PushTrackedMessageRole>{};
  final Map<String, String> permissionRequestToSession = <String, String>{};

  late final _SpyPushSessionStateMutator mutator = _SpyPushSessionStateMutator(
    sessions: sessions,
    messageRoles: messageRoles,
    permissionRequestToSession: permissionRequestToSession,
  );
  late final PushSessionEventReducer reducer = PushSessionEventReducer(
    sessions: sessions,
    messageRoles: messageRoles,
    permissionRequestToSession: permissionRequestToSession,
    mutator: mutator,
  );

  void handle({required SesoriSseEvent event, required DateTime now}) {
    reducer.handleEvent(event: event, now: now);
  }
}

class _SpyPushSessionStateMutator extends PushSessionStateMutator {
  final List<({Session session, DateTime touchedAt})> upsertCalls = <({Session session, DateTime touchedAt})>[];
  final List<String> deletedSessionIds = <String>[];
  final List<({String sessionId, String messageId, DateTime? touchedAt})> trackMessageCalls =
      <({String sessionId, String messageId, DateTime? touchedAt})>[];
  final List<String> untrackMessageIds = <String>[];
  final List<MessagePart> updateLatestAssistantTextParts = <MessagePart>[];
  final List<({List<ProjectActivitySummary> projects, DateTime touchedAt})> applyProjectsSummaryCalls =
      <({List<ProjectActivitySummary> projects, DateTime touchedAt})>[];

  _SpyPushSessionStateMutator({
    required super.sessions,
    required super.messageRoles,
    required super.permissionRequestToSession,
  });

  @override
  void upsertSession({required Session session, required DateTime touchedAt}) {
    upsertCalls.add((session: session, touchedAt: touchedAt));
    super.upsertSession(session: session, touchedAt: touchedAt);
  }

  @override
  void deleteSession({required String sessionId}) {
    deletedSessionIds.add(sessionId);
    super.deleteSession(sessionId: sessionId);
  }

  @override
  void trackMessageForSession({required String sessionId, required String messageId, DateTime? touchedAt}) {
    trackMessageCalls.add((sessionId: sessionId, messageId: messageId, touchedAt: touchedAt));
    super.trackMessageForSession(sessionId: sessionId, messageId: messageId, touchedAt: touchedAt);
  }

  @override
  String? untrackMessage({required String messageId}) {
    untrackMessageIds.add(messageId);
    return super.untrackMessage(messageId: messageId);
  }

  @override
  void updateLatestAssistantText({required MessagePart part}) {
    updateLatestAssistantTextParts.add(part);
    super.updateLatestAssistantText(part: part);
  }

  @override
  void applyProjectsSummaryChildLinks({required List<ProjectActivitySummary> projects, required DateTime touchedAt}) {
    applyProjectsSummaryCalls.add((projects: projects, touchedAt: touchedAt));
    super.applyProjectsSummaryChildLinks(projects: projects, touchedAt: touchedAt);
  }
}

PushTrackedSessionState _trackedSessionState({
  String? parentId,
  String? projectId,
  String? title,
  SessionStatus? status,
  bool previouslyBusy = false,
  Set<String> childIds = const <String>{},
  Set<String> messageIds = const <String>{},
  String? latestAssistantText,
  bool hasPendingQuestion = false,
  bool hasPendingPermission = false,
  DateTime? lastTouchedAt,
}) {
  final sessionState = PushTrackedSessionState();
  sessionState.parentId = parentId;
  sessionState.projectId = projectId;
  sessionState.title = title;
  sessionState.status = status;
  sessionState.previouslyBusy = previouslyBusy;
  sessionState.childIds.addAll(childIds);
  sessionState.messageIds.addAll(messageIds);
  sessionState.latestAssistantText = latestAssistantText;
  sessionState.hasPendingQuestion = hasPendingQuestion;
  sessionState.hasPendingPermission = hasPendingPermission;
  sessionState.lastTouchedAt = lastTouchedAt;
  return sessionState;
}

PushTrackedMessageRole _trackedMessageRole({
  required String role,
  required String sessionId,
  required DateTime updatedAt,
}) {
  return PushTrackedMessageRole(
    role: role,
    sessionId: sessionId,
    updatedAt: updatedAt,
  );
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

Message _message({
  required String id,
  required String role,
  required String sessionID,
}) {
  return Message(
    id: id,
    role: role,
    sessionID: sessionID,
    agent: null,
    modelID: null,
    providerID: null,
  );
}

MessagePart _textPart({
  required String sessionID,
  required String messageID,
  required String text,
}) {
  return MessagePart(
    id: "part-$messageID",
    sessionID: sessionID,
    messageID: messageID,
    type: MessagePartType.text,
    text: text,
    tool: null,
    state: null,
    prompt: null,
    description: null,
    agent: null,
    agentName: null,
    attempt: null,
    retryError: null,
  );
}

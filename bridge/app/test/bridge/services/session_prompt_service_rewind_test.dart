import "dart:convert";

import "package:sesori_bridge/src/api/database/daos/accepted_prompts_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/foundation/session_archived_read_only_exception.dart";
import "package:sesori_bridge/src/repositories/accepted_prompts_repository.dart";
import "package:sesori_bridge/src/repositories/models/history_window.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/rewind_session_handler.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/session_branch_refused_exception.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_prompt_service.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show buildWorktreeSystemContext;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_session_options_service.dart";
import "../../helpers/session_continuation_test_support.dart";
import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

/// Two answered turns: `u1` opens the first, `u2` the second.
final _transcript = [
  _user(id: "u1", text: "first"),
  _agent(id: "a1", text: "first answer"),
  _user(id: "u2", text: "second"),
  _agent(id: "a2", text: "second answer"),
];

void main() {
  late _FakeRewindPlugin plugin;
  late AppDatabase db;
  late SessionRepository sessionRepository;
  late SessionOperationDispatcher dispatcher;
  late TestChatHistory history;
  late _RecordingRewindMutations mutations;
  late RecordingSessionContinuations continuations;
  late SessionPromptService service;

  /// The harness the session runs on; a test swaps it before `setUp` runs.
  BridgePluginApi Function() sessionPlugin = () => plugin;

  SessionPromptService createService() {
    sessionRepository = singlePluginSessionRepository(
      plugin: sessionPlugin(),
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    dispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
    history = createTestChatHistory(sessionRepository: sessionRepository);
    return SessionPromptService(
      continuations: continuations = RecordingSessionContinuations(),
      mutations: mutations = _RecordingRewindMutations(),
      views: const PassThroughSessionViews(),
      sessionRepository: sessionRepository,
      acceptedPromptsRepository: AcceptedPromptsRepository(dao: AcceptedPromptsDao(database: db)),
      dispatcher: dispatcher,
      archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
      sessionOptionsService: FakeSessionOptionsService(),
      promptPartDelivery: testPromptPartDeliveryService(uploadsRoot: "/uploads"),
      chatHistory: history.service,
    );
  }

  setUp(() async {
    db = createTestDatabase();
    plugin = _FakeRewindPlugin()..messagesResult = _transcript;
    service = createService();
    await insertTestSession(
      db: db,
      sessionId: "s1",
      backendSessionId: "backend-s1",
      pluginId: "fake",
      projectId: "/repo",
      isDedicated: false,
      createdAt: 1,
      worktreePath: null,
      baseBranch: null,
      baseCommit: null,
      agent: null,
      agentModel: null,
    );
  });

  tearDown(() async {
    await service.dispose();
    await dispatcher.dispose();
    await plugin.close();
    await db.close();
  });

  Future<void> rewind({required String messageId, String promptId = "edit-1"}) => service.rewindAndSendPrompt(
    sessionId: "s1",
    messageId: messageId,
    promptId: promptId,
    parts: const [PromptPart.text(text: "second, edited")],
    variant: null,
    fastMode: false,
    agent: null,
    model: null,
  );

  Future<List<String>> storedIds() async {
    final page = await history.service.getSessionMessages(
      sessionId: "s1",
      window: const HistoryWindowAll(),
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
      toolOutputDelivery: ToolOutputDelivery.onExpand,
      storedOnly: true,
      backgroundRefresh: false,
    );
    return [for (final message in page.messages) message.info.id];
  }

  Matcher refusedWith(SessionBranchErrorCode code) =>
      throwsA(isA<SessionBranchRefusedException>().having((error) => error.code, "code", code));

  test("rewinds a later turn and publishes exactly the removed messages", () async {
    await rewind(messageId: "u2");

    expect(continuations.cancellations, ["s1"]);

    expect(plugin.rewinds, [
      (sessionId: "backend-s1", beforeMessageId: "u2", promptId: "edit-1", text: "second, edited"),
    ]);
    expect(mutations.rewound.single.sessionId, "s1");
    expect(mutations.rewound.single.removedMessageIds, ["u2", "a2"]);
  });

  test("keeps the edited prompt captured during the call out of the removed messages", () async {
    plugin.onRewind = () => history.service.captureMessage(
      sessionId: "s1",
      message: const Message.user(
        invocation: null,
        id: "u2-edited",
        sessionID: "s1",
        agent: null,
        time: null,
        promptId: "edit-1",
        handoff: null,
      ),
    );

    await rewind(messageId: "u2");
    for (final id in mutations.rewound.single.removedMessageIds) {
      await history.service.captureMessageRemoved(sessionId: "s1", messageId: id, shouldCapture: () => true);
    }

    expect(mutations.rewound.single.removedMessageIds, ["u2", "a2"]);
    expect(await storedIds(), ["u1", "a1", "u2-edited"]);
  });

  test("a retry with the same prompt id succeeds without rewinding again", () async {
    await rewind(messageId: "u2");
    // The retry arrives after the rewind already dropped u2.
    plugin.messagesResult = _transcript.take(2).toList();

    await rewind(messageId: "u2");

    expect(plugin.rewinds, hasLength(1));
    expect(mutations.rewound, hasLength(1));
  });

  test("refuses a running session without reaching the plugin", () async {
    plugin.activeSummaries = const [
      PluginProjectActivitySummary(
        id: "/repo",
        activeSessions: [PluginActiveSession(id: "backend-s1", mainAgentRunning: true)],
      ),
    ];

    await expectLater(rewind(messageId: "u2"), refusedWith(SessionBranchErrorCode.sessionBusy));
    expect(plugin.rewinds, isEmpty);
    expect(mutations.rewound, isEmpty);
    expect(continuations.cancellations, isEmpty, reason: "a refused edit leaves a pending continuation alone");
  });

  test("backfills a partial store before validating the turn", () async {
    // Only the first prompt was captured live; the store was never synced.
    await history.service.captureMessage(
      sessionId: "s1",
      message: const Message.user(
        invocation: null,
        id: "u1",
        sessionID: "s1",
        agent: null,
        time: null,
        promptId: null,
        handoff: null,
      ),
    );

    await rewind(messageId: "u2");

    expect(plugin.lastGetMessagesSessionId, "backend-s1");
    expect(mutations.rewound.single.removedMessageIds, ["u2", "a2"]);
  });

  test("refuses a message that does not open a turn", () async {
    await expectLater(rewind(messageId: "a1"), refusedWith(SessionBranchErrorCode.branchPointUnavailable));
    expect(plugin.rewinds, isEmpty);
    expect(continuations.cancellations, isEmpty);
  });

  group("a first-turn edit", () {
    setUp(() {
      plugin.createSessionResult = const PluginSession(
        id: "backend-s1-new",
        projectID: "/repo",
        directory: "/repo",
        parentID: null,
        title: null,
        time: null,
      );
    });

    List<String> createdTexts() => [
      for (final part in plugin.lastCreateSessionParts ?? fail("no harness session was created"))
        if (part case PluginPromptPartText(:final text)) text,
    ];

    Future<void> insertChild() async {
      await insertTestSession(
        db: db,
        sessionId: "s1-child",
        backendSessionId: "backend-child",
        pluginId: "fake",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 2,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
      await db.sessionDao.setParentSessionId(sessionId: "s1-child", parentSessionId: "s1");
    }

    test("moves the session onto a new harness session and deletes the old one", () async {
      await rewind(messageId: "u1");

      expect(plugin.rewinds, isEmpty);
      expect(continuations.cancellations, ["s1"]);
      expect(plugin.lastCreateSessionDirectory, "/repo");
      expect(plugin.lastCreateSessionParentId, isNull);
      expect(createdTexts(), ["second, edited"]);
      expect(plugin.lastCreateSessionUserVisibleText, "second, edited");
      expect((await db.sessionDao.getSession(sessionId: "s1"))?.backendSessionId, "backend-s1-new");
      expect(plugin.lastDeleteSessionId, "backend-s1");
      // Catalog import and startup cleanup both skip the tombstoned old one.
      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "backend-s1", pluginId: "fake"), isTrue);
      expect(await sessionRepository.isSessionTombstoned(sessionId: "s1"), isFalse);
      expect(mutations.rewound.single.removedMessageIds, ["u1", "a1", "u2", "a2"]);
    });

    test("removes the old sub-agent rows and their history", () async {
      await insertChild();
      await history.service.captureMessage(
        sessionId: "s1-child",
        message: const Message.user(
          invocation: null,
          id: "child-u1",
          sessionID: "s1-child",
          agent: null,
          time: null,
          promptId: null,
          handoff: null,
        ),
      );

      await rewind(messageId: "u1");

      expect(await db.sessionDao.getSession(sessionId: "s1-child"), isNull);
      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "backend-child", pluginId: "fake"), isTrue);
      expect(await sessionRepository.isSessionTombstoned(sessionId: "s1-child"), isTrue);
      final childHistory = await history.repository.getSessionMessages(
        sessionId: "s1-child",
        storageScope: testAttachmentStorageScope(sessionId: "backend-child"),
      );
      expect(childHistory.messages, isEmpty);
    });

    test("still succeeds when the old harness session cannot be deleted", () async {
      plugin.throwOnDeleteSessionError = const PluginOperationException(
        operation: "deleteSession",
        statusCode: 500,
        message: "backend down",
      );

      await rewind(messageId: "u1");

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.backendSessionId, "backend-s1-new");
      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "backend-s1", pluginId: "fake"), isTrue);
      expect(mutations.rewound.single.removedMessageIds, ["u1", "a1", "u2", "a2"]);
    });

    test("replaces a row catalog import bound to the new harness session first", () async {
      await insertTestSession(
        db: db,
        sessionId: "imported",
        backendSessionId: "backend-s1-new",
        pluginId: "fake",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 3,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        agent: null,
        agentModel: null,
      );

      await rewind(messageId: "u1");

      expect(await db.sessionDao.getSession(sessionId: "imported"), isNull);
      expect(
        (await db.sessionDao.getSessionByBinding(pluginId: "fake", backendSessionId: "backend-s1-new"))?.sessionId,
        "s1",
      );
      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "backend-s1-new", pluginId: "fake"), isFalse);
    });

    test("does not delete the old harness session when the new one cannot be created", () async {
      await insertChild();
      plugin.createSessionError = const PluginOperationException(
        operation: "createSession",
        statusCode: 500,
        message: "backend down",
      );

      await expectLater(rewind(messageId: "u1"), throwsA(isA<PluginOperationException>()));

      expect((await db.sessionDao.getSession(sessionId: "s1"))?.backendSessionId, "backend-s1");
      expect(await db.sessionDao.getSession(sessionId: "s1-child"), isNotNull);
      expect(plugin.lastDeleteSessionId, isNull);
      expect(await db.sessionDao.isSessionTombstoned(backendSessionId: "backend-s1", pluginId: "fake"), isFalse);
      expect(mutations.rewound, isEmpty);
    });
  });

  group("a first-turn edit in a dedicated worktree", () {
    setUp(() async {
      plugin.createSessionResult = const PluginSession(
        id: "backend-s2-new",
        projectID: "/repo",
        directory: "/repo/.worktrees/s2",
        parentID: null,
        title: null,
        time: null,
      );
      await insertTestSession(
        db: db,
        sessionId: "s2",
        backendSessionId: "backend-s2",
        pluginId: "fake",
        projectId: "/repo",
        isDedicated: true,
        createdAt: 1,
        worktreePath: "/repo/.worktrees/s2",
        baseBranch: "main",
        baseCommit: null,
        agent: null,
        agentModel: null,
      );
    });

    test("starts the new harness session with the worktree context", () async {
      await service.rewindAndSendPrompt(
        sessionId: "s2",
        messageId: "u1",
        promptId: "edit-1",
        parts: const [PromptPart.text(text: "first, edited")],
        variant: null,
        fastMode: false,
        agent: null,
        model: null,
      );

      expect(plugin.lastCreateSessionDirectory, "/repo/.worktrees/s2");
      final texts = [
        for (final part in plugin.lastCreateSessionParts ?? fail("no harness session was created"))
          if (part case PluginPromptPartText(:final text)) text,
      ];
      expect(texts, [
        buildWorktreeSystemContext(worktreePath: "/repo/.worktrees/s2", baseBranch: "main"),
        "first, edited",
      ]);
      expect(plugin.lastCreateSessionUserVisibleText, "first, edited");
    });
  });

  group("on a harness without native rewind", () {
    final plainPlugin = FakeBridgePlugin()..messagesResult = _transcript;
    setUpAll(() => sessionPlugin = () => plainPlugin);
    tearDownAll(() async {
      sessionPlugin = () => plugin;
      await plainPlugin.close();
    });

    test("refuses the edit", () async {
      await expectLater(rewind(messageId: "u2"), refusedWith(SessionBranchErrorCode.branchPointUnavailable));
    });
  });

  test("passes the plugin's own reason through when it cannot rewind", () async {
    plugin.rewindError = const PluginBranchPointUnavailableException(
      operation: "rewindAndSendPrompt",
      userFacingReason: "This message was compacted.",
      cause: null,
    );

    await expectLater(
      rewind(messageId: "u2"),
      throwsA(
        isA<SessionBranchRefusedException>()
            .having((error) => error.code, "code", SessionBranchErrorCode.branchPointUnavailable)
            .having((error) => error.message, "message", "This message was compacted."),
      ),
    );
    expect(mutations.rewound, isEmpty);
  });

  test("maps stale prompt options to a branch refusal", () async {
    plugin.rewindError = const PluginStaleOptionsException(operation: "rewindAndSendPrompt", message: "unknown agent");

    await expectLater(rewind(messageId: "u2"), refusedWith(SessionBranchErrorCode.staleSessionOptions));
    expect(mutations.rewound, isEmpty);
  });

  test("the route answers a refusal with 409 and the branch error code", () async {
    final response = await RewindSessionHandler(sessionPromptService: service).routeForTest(
      makeRequest(
        "POST",
        "/session/rewind",
        body: jsonEncode(
          const RewindSessionRequest(
            sessionId: "s1",
            messageId: "a1",
            promptId: "edit-1",
            parts: [PromptPart.text(text: "first, edited")],
            agent: null,
            model: null,
            variant: null,
            fastMode: false,
          ).toJson(),
        ),
      ),
    );

    expect(response.status, 409);
    final parsed = SessionBranchErrorResponse.fromJson(
      jsonDecode(response.body ?? fail("missing body")) as Map<String, dynamic>,
    );
    expect(parsed.code, SessionBranchErrorCode.branchPointUnavailable);
    expect(parsed.message, isNull);
  });

  test("refuses an archived session without reaching the plugin", () async {
    await db.sessionDao.setArchived(sessionId: "s1", archivedAt: 5, updatedAt: 5, projectionUpdatedAt: 5);

    await expectLater(rewind(messageId: "u2"), throwsA(isA<SessionArchivedReadOnlyException>()));
    expect(plugin.rewinds, isEmpty);
  });
}

PluginMessageWithParts _user({required String id, required String text}) => PluginMessageWithParts(
  info: PluginMessage.user(promptId: null, invocation: null, id: id, sessionID: "backend-s1", agent: null, time: null),
  parts: [PluginMessagePart.text(id: "$id-text", sessionID: "backend-s1", messageID: id, text: text)],
);

PluginMessageWithParts _agent({required String id, required String text}) => PluginMessageWithParts(
  info: PluginMessage.assistant(
    id: id,
    sessionID: "backend-s1",
    agent: null,
    modelID: null,
    providerID: null,
    variant: null,
    sender: PluginMessageSender.agent,
    time: null,
  ),
  parts: [PluginMessagePart.text(id: "$id-text", sessionID: "backend-s1", messageID: id, text: text)],
);

class _FakeRewindPlugin() extends FakeBridgePlugin implements SessionRewindPluginApi {
  final List<({String sessionId, String beforeMessageId, String promptId, String text})> rewinds = [];
  List<PluginProjectActivitySummary> activeSummaries = [];
  Object? rewindError;
  Future<void> Function()? onRewind;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => activeSummaries;

  @override
  Future<void> rewindAndSendPrompt({
    required String sessionId,
    required String beforeMessageId,
    required String promptId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    if (rewindError case final error?) throw error;
    await onRewind?.call();
    rewinds.add((
      sessionId: sessionId,
      beforeMessageId: beforeMessageId,
      promptId: promptId,
      text: [
        for (final part in parts)
          if (part case PluginPromptPartText(:final text)) text,
      ].join(),
    ));
  }
}

final class _RecordingRewindMutations() implements SessionMutationDispatcher {
  final List<({String sessionId, List<String> removedMessageIds})> rewound = [];

  @override
  void messagesRewound({required Session session, required List<String> removedMessageIds}) {
    rewound.add((sessionId: session.id, removedMessageIds: removedMessageIds));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

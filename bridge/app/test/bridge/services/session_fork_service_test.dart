import "dart:convert";
import "dart:io" show FileSystemEntityType;

import "package:sesori_bridge/src/api/database/daos/accepted_prompts_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/repositories/accepted_prompts_repository.dart";
import "package:sesori_bridge/src/repositories/models/history_window.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/routing/fork_session_handler.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/session_branch_refused_exception.dart";
import "package:sesori_bridge/src/services/session_fork_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_prompt_service.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show buildWorktreeSystemContext;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/fake_session_options_service.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/session_continuation_test_support.dart";
import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

/// Two answered turns. `f1` is a follow-up sent before the first turn's
/// answer, so it joins that turn.
final _transcript = [
  _user(id: "u1", text: "first"),
  _user(id: "f1", text: "and also"),
  _agent(id: "a1", text: "first answer"),
  _user(id: "u2", text: "second"),
  _agent(id: "a2", text: "second answer"),
];

const _worktree = "/worktrees/w1";

void main() {
  late _FakeForkPlugin plugin;
  late AppDatabase db;
  late SessionRepository sessionRepository;
  late SessionOperationDispatcher dispatcher;
  late TestChatHistory history;
  late _FakeWorktreeGit git;
  late _FakeWorktreeDisk disk;
  late WorktreeRepository worktrees;
  late SessionForkService service;

  setUp(() async {
    db = createTestDatabase();
    plugin = _FakeForkPlugin()..messagesByBackendId["backend-s1"] = _transcript;
    sessionRepository = singlePluginSessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    dispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
    history = createTestChatHistory(sessionRepository: sessionRepository);
    git = _FakeWorktreeGit()..worktrees.add(_worktree);
    disk = _FakeWorktreeDisk(git: git);
    worktrees = WorktreeRepository(
      worktreesDirectory: "/worktrees",
      projectsDao: db.projectsDao,
      filesystemApi: disk,
      gitApi: git,
      runtime: createTestPluginRuntime(plugins: [plugin]),
    );
    service = SessionForkService(
      sessionRepository: sessionRepository,
      chatHistory: history.service,
      worktrees: worktrees,
      views: _CatalogViews(sessions: sessionRepository),
      dispatcher: dispatcher,
    );
    await insertTestSession(
      db: db,
      sessionId: "s1",
      backendSessionId: "backend-s1",
      pluginId: "fake",
      projectId: "/repo",
      isDedicated: true,
      createdAt: 1,
      worktreePath: _worktree,
      baseBranch: "main",
      baseCommit: "abc123",
      agent: "build",
      agentModel: const AgentModel(providerID: "p", modelID: "m", variant: null),
    );
    await db.customStatement(
      "UPDATE sessions_table SET branch_name = 'feature', fast_mode = 1 WHERE session_id = 's1'",
    );
    await db.sessionDao.setTitle(sessionId: "s1", title: "Origin", updatedAt: 1, projectionUpdatedAt: 1);
    await db.sessionDao.setApprovalOverride(sessionId: "s1", approvalOverride: SessionApprovalMode.values.first);
  });

  tearDown(() async {
    await dispatcher.dispose();
    await plugin.close();
    await db.close();
  });

  Future<Session> fork(ForkPoint point) => service.forkSession(sessionId: "s1", point: point, recreateFromBase: false);

  /// The retry after a `worktreeBranchMissing` refusal.
  Future<Session> forkFromBase(ForkPoint point) =>
      service.forkSession(sessionId: "s1", point: point, recreateFromBase: true);

  Matcher refusedWith(SessionBranchErrorCode code) =>
      throwsA(isA<SessionBranchRefusedException>().having((error) => error.code, "code", code));

  void runningSecondTurn() => plugin.activeSummaries = const [
    PluginProjectActivitySummary(
      id: "/repo",
      activeSessions: [PluginActiveSession(id: "backend-s1", mainAgentRunning: true)],
    ),
  ];

  Future<List<String>> storedIds({required String sessionId}) async {
    final page = await history.service.getSessionMessages(
      sessionId: sessionId,
      window: const HistoryWindowAll(),
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
      toolOutputDelivery: ToolOutputDelivery.onExpand,
      storedOnly: true,
      backgroundRefresh: false,
    );
    return [for (final message in page.messages) message.info.id];
  }

  group("fork points", () {
    test("after an agent reply keeps through the end of its turn", () async {
      await fork(const ForkPoint.afterMessage(messageId: "a1"));

      expect(plugin.forks, [(sessionId: "backend-s1", throughMessageId: "a1")]);
    });

    test("after a follow-up sent mid-turn keeps the whole turn holding it", () async {
      await fork(const ForkPoint.afterMessage(messageId: "f1"));

      expect(plugin.forks, [(sessionId: "backend-s1", throughMessageId: "a1")]);
    });

    test("before a later turn's prompt keeps every turn before it", () async {
      await fork(const ForkPoint.beforeMessage(messageId: "u2"));

      expect(plugin.forks, [(sessionId: "backend-s1", throughMessageId: "a1")]);
    });

    test("before the first prompt creates an unstarted session in the same directory", () async {
      final forked = await fork(const ForkPoint.beforeMessage(messageId: "u1"));

      expect(plugin.forks, isEmpty);
      expect(plugin.lastCreateSessionDirectory, _worktree);
      expect(plugin.lastCreateSessionParts, isEmpty);
      expect(plugin.lastCreateSessionParentId, isNull);
      expect(forked.forkedFrom, const SessionForkOrigin(sessionId: "s1", title: "Origin"));
    });

    test("before a follow-up is refused: it opens no turn", () async {
      await expectLater(
        fork(const ForkPoint.beforeMessage(messageId: "f1")),
        refusedWith(SessionBranchErrorCode.branchPointUnavailable),
      );
      expect(plugin.forks, isEmpty);
    });

    test("an unknown message is refused", () async {
      await expectLater(
        fork(const ForkPoint.afterMessage(messageId: "missing")),
        refusedWith(SessionBranchErrorCode.branchPointUnavailable),
      );
    });

    test("latest keeps through the last turn of an idle session", () async {
      await fork(const ForkPoint.latest());

      expect(plugin.forks, [(sessionId: "backend-s1", throughMessageId: "a2")]);
    });

    test("latest skips the running turn", () async {
      runningSecondTurn();

      await fork(const ForkPoint.latest());

      expect(plugin.forks, [(sessionId: "backend-s1", throughMessageId: "a1")]);
    });

    test("latest with no finished turn answers nothingToFork", () async {
      plugin.messagesByBackendId["backend-s1"] = _transcript.take(1).toList();
      runningSecondTurn();

      await expectLater(fork(const ForkPoint.latest()), refusedWith(SessionBranchErrorCode.nothingToFork));
    });

    test("latest on an empty session answers nothingToFork", () async {
      plugin.messagesByBackendId["backend-s1"] = const [];

      await expectLater(fork(const ForkPoint.latest()), refusedWith(SessionBranchErrorCode.nothingToFork));
    });

    test("a message of the running turn is refused as busy", () async {
      runningSecondTurn();

      await expectLater(
        fork(const ForkPoint.afterMessage(messageId: "a2")),
        refusedWith(SessionBranchErrorCode.sessionBusy),
      );
      expect(plugin.forks, isEmpty);
    });

    test("an earlier finished turn forks while a later one runs", () async {
      runningSecondTurn();

      await fork(const ForkPoint.afterMessage(messageId: "a1"));

      expect(plugin.forks, [(sessionId: "backend-s1", throughMessageId: "a1")]);
    });
  });

  group("the fork's row", () {
    test("is a root copying the origin's worktree and prompt defaults, not its approval override", () async {
      final forked = await fork(const ForkPoint.afterMessage(messageId: "a1"));

      final row = await db.sessionDao.getSession(sessionId: forked.id) ?? fail("missing fork row");
      expect(row.backendSessionId, "backend-fork");
      expect(row.parentSessionId, isNull);
      expect(row.projectId, "/repo");
      expect(row.directory, _worktree);
      expect(row.worktreePath, _worktree);
      expect(row.branchName, "feature");
      expect(row.isDedicated, isTrue);
      expect(row.baseBranch, "main");
      expect(row.baseCommit, "abc123");
      expect(row.lastAgent, "build");
      expect(row.lastAgentModel, const AgentModel(providerID: "p", modelID: "m", variant: null));
      expect(row.fastMode, isTrue);
      expect(row.approvalOverride, isNull);
      expect(row.forkedFromSessionId, "s1");
      expect(row.forkedFromTitle, "Origin");
      expect(forked.title, "Origin (fork)");
      expect(forked.forkedFrom, const SessionForkOrigin(sessionId: "s1", title: "Origin"));
      expect(forked.hasWorktree, isTrue);
    });

    test("opens with the kept turns", () async {
      plugin.messagesByBackendId["backend-fork"] = _transcript.take(3).toList();

      final forked = await fork(const ForkPoint.afterMessage(messageId: "a1"));

      expect(await storedIds(sessionId: forked.id), ["u1", "f1", "a1"]);
    });

    test("of an untitled origin is untitled and names no origin title", () async {
      await db.sessionDao.setTitle(sessionId: "s1", title: null, updatedAt: 1, projectionUpdatedAt: 1);

      final forked = await fork(const ForkPoint.afterMessage(messageId: "a1"));

      expect(forked.title, isNull);
      expect(forked.forkedFrom, const SessionForkOrigin(sessionId: "s1", title: null));
    });

    test("keeps naming its origin after the origin is deleted", () async {
      final forked = await fork(const ForkPoint.afterMessage(messageId: "a1"));

      await db.sessionDao.deleteSession(sessionId: "s1");

      final reread = await sessionRepository.getCatalogSession(sessionId: forked.id) ?? fail("missing fork");
      expect(reread.forkedFrom, const SessionForkOrigin(sessionId: null, title: "Origin"));
    });

    test("reuses the row catalog import already bound to the forked backend session", () async {
      await insertTestSession(
        db: db,
        sessionId: "imported",
        backendSessionId: "backend-fork",
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

      final forked = await fork(const ForkPoint.afterMessage(messageId: "a1"));

      expect(forked.id, "imported");
      final row = await db.sessionDao.getSession(sessionId: "imported") ?? fail("missing imported row");
      expect(row.worktreePath, _worktree);
      expect(row.forkedFromSessionId, "s1");
      expect(row.forkedFromTitle, "Origin");
    });

    test("shares the worktree: either session keeps it while the other is live", () async {
      final forked = await fork(const ForkPoint.afterMessage(messageId: "a1"));

      Future<List<String>> sharers(String sessionId) async => [
        for (final row in await db.sessionDao.getOtherActiveSessionsSharing(
          sessionId: sessionId,
          projectId: "/repo",
          worktreePath: _worktree,
        ))
          row.sessionId,
      ];

      expect(await sharers("s1"), [forked.id]);
      expect(await sharers(forked.id), ["s1"]);

      await db.sessionDao.setArchived(sessionId: forked.id, archivedAt: 5, updatedAt: 5, projectionUpdatedAt: 5);
      expect(await sharers("s1"), isEmpty, reason: "the last live session removes the worktree");

      await db.sessionDao.deleteSession(sessionId: forked.id);
      expect(await sharers("s1"), isEmpty);
    });
  });

  group("refusals", () {
    test("a harness without native fork cannot fork at a message", () async {
      final repository = singlePluginSessionRepository(
        plugin: FakeBridgePlugin()..messagesResult = _transcript,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final localDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      addTearDown(localDispatcher.dispose);
      final localService = SessionForkService(
        sessionRepository: repository,
        chatHistory: createTestChatHistory(sessionRepository: repository).service,
        worktrees: worktrees,
        views: _CatalogViews(sessions: repository),
        dispatcher: localDispatcher,
      );

      await expectLater(
        localService.forkSession(
          sessionId: "s1",
          point: const ForkPoint.afterMessage(messageId: "a1"),
          recreateFromBase: false,
        ),
        refusedWith(SessionBranchErrorCode.branchPointUnavailable),
      );
    });

    test("a harness that cannot map the message refuses with its own reason", () async {
      plugin.forkError = const PluginBranchPointUnavailableException(
        operation: "forkSession",
        userFacingReason: "This conversation is no longer stored.",
        cause: null,
      );

      await expectLater(
        fork(const ForkPoint.afterMessage(messageId: "a1")),
        throwsA(
          isA<SessionBranchRefusedException>()
              .having((error) => error.code, "code", SessionBranchErrorCode.branchPointUnavailable)
              .having((error) => error.message, "message", "This conversation is no longer stored."),
        ),
      );
      expect(await db.sessionDao.getSessionByBinding(pluginId: "fake", backendSessionId: "backend-fork"), isNull);
    });

    test("a sub-agent session cannot be forked", () async {
      await insertTestSession(
        db: db,
        sessionId: "child",
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
      await db.sessionDao.setParentSessionId(sessionId: "child", parentSessionId: "s1");
      plugin.messagesByBackendId["backend-child"] = _transcript;

      await expectLater(
        service.forkSession(sessionId: "child", point: const ForkPoint.latest(), recreateFromBase: false),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 409)),
      );
      expect(plugin.forks, isEmpty);
    });
  });

  Future<void> archiveOrigin() async {
    await history.service.backfillSession(sessionId: "s1");
    await history.service.exportSessionHistory(
      session: await sessionRepository.getStoredSession(sessionId: "s1") ?? fail("missing origin"),
      title: "Origin",
      createdAt: 1,
      updatedAt: 2,
      archivedAt: 3,
    );
    await db.sessionDao.setArchived(sessionId: "s1", archivedAt: 3, updatedAt: 3, projectionUpdatedAt: 3);
    // The harness now reports nothing: only the audit record has the turns.
    plugin.messagesByBackendId["backend-s1"] = const [];
  }

  test("an archived origin forks from its audit record and keeps its worktree", () async {
    await archiveOrigin();

    final forked = await fork(const ForkPoint.latest());

    expect(plugin.forks, [(sessionId: "backend-s1", throughMessageId: "a2")]);
    expect(forked.time?.archived, isNull);
    expect(forked.hasWorktree, isTrue);
    final origin = await db.sessionDao.getSession(sessionId: "s1") ?? fail("missing origin");
    expect(origin.archivedAt, 3, reason: "a fork only reads its origin");
  });

  group("an archived origin whose worktree was removed", () {
    setUp(() async {
      await archiveOrigin();
      git.worktrees.clear();
    });

    test("gets it back at the same path on its kept branch before the harness forks", () async {
      git.branches.add("feature");

      final forked = await fork(const ForkPoint.latest());

      expect(git.added, ["$_worktree on feature"]);
      expect(plugin.forks, [(sessionId: "backend-s1", throughMessageId: "a2")]);
      final row = await db.sessionDao.getSession(sessionId: forked.id) ?? fail("missing fork");
      expect(row.worktreePath, _worktree);
      expect(
        await db.sessionDao.getOtherActiveSessionsSharing(
          sessionId: forked.id,
          projectId: "/repo",
          worktreePath: _worktree,
        ),
        isEmpty,
        reason: "the archived origin is no sharer, so the fork's archive or deletion removes the worktree",
      );
    });

    test("whose branch is gone gets it back at the HEAD archiving kept", () async {
      git.keptHead = "work123";

      await fork(const ForkPoint.latest());

      expect(git.added, ["$_worktree on new feature from work123"]);
      expect(plugin.forks, hasLength(1));
    });

    test("that kept nothing answers worktreeBranchMissing and creates nothing", () async {
      await expectLater(
        fork(const ForkPoint.latest()),
        refusedWith(SessionBranchErrorCode.worktreeBranchMissing),
      );

      expect(git.added, isEmpty);
      expect(plugin.forks, isEmpty);
    });

    test("that kept nothing gets the branch again from its base commit on the retry", () async {
      await forkFromBase(const ForkPoint.latest());

      expect(git.added, ["$_worktree on new feature from abc123"]);
      expect(plugin.forks, hasLength(1));
    });

    test("is refused when something else now holds the path", () async {
      disk.otherEntries.add(_worktree);

      await expectLater(
        forkFromBase(const ForkPoint.latest()),
        refusedWith(SessionBranchErrorCode.refused),
      );

      expect(git.added, isEmpty);
      expect(plugin.forks, isEmpty);
    });

    test("is refused when git cannot add the worktree", () async {
      git
        ..branches.add("feature")
        ..addSucceeds = false;

      await expectLater(fork(const ForkPoint.latest()), refusedWith(SessionBranchErrorCode.refused));

      expect(plugin.forks, isEmpty);
    });
  });

  test("a live origin's worktree is never recreated", () async {
    git.worktrees.clear();

    await fork(const ForkPoint.latest());

    expect(git.added, isEmpty);
  });

  test("an empty fork's first prompt carries the worktree context, later prompts do not", () async {
    final forked = await fork(const ForkPoint.beforeMessage(messageId: "u1"));
    final prompts = SessionPromptService(
      continuations: RecordingSessionContinuations(),
      mutations: const UnusedContinuationMutations(),
      views: const PassThroughSessionViews(),
      sessionRepository: sessionRepository,
      acceptedPromptsRepository: AcceptedPromptsRepository(dao: AcceptedPromptsDao(database: db)),
      dispatcher: dispatcher,
      archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
      sessionOptionsService: FakeSessionOptionsService(),
      promptPartDelivery: testPromptPartDeliveryService(uploadsRoot: "/uploads"),
      chatHistory: history.service,
    );
    addTearDown(prompts.dispose);
    Future<List<String>> send(String promptId) async {
      await prompts.sendPrompt(
        sessionId: forked.id,
        promptId: promptId,
        parts: const [PromptPart.text(text: "hello")],
        variant: null,
        fastMode: false,
        agent: null,
        model: null,
        command: null,
        commandSource: null,
        handoff: null,
      );
      return [
        for (final part in plugin.lastSendPromptParts ?? fail("no prompt sent"))
          if (part case PluginPromptPartText(:final text)) text,
      ];
    }

    expect(await send("p1"), [buildWorktreeSystemContext(worktreePath: _worktree, baseBranch: "main"), "hello"]);

    await history.service.captureMessage(
      sessionId: forked.id,
      message: Message.user(
        invocation: null,
        id: "fork-u1",
        sessionID: forked.id,
        agent: null,
        time: null,
        promptId: "p1",
        handoff: null,
      ),
    );
    expect(await send("p2"), ["hello"]);
  });

  test("POST /session/fork answers the new session, and a refusal answers SessionBranchErrorResponse", () async {
    final handler = ForkSessionHandler(sessionForkService: service);
    RelayRequest request(ForkPoint point) => makeRequest(
      "POST",
      "/session/fork",
      body: jsonEncode(ForkSessionRequest(sessionId: "s1", point: point, recreateFromBase: false).toJson()),
    );

    final created = await handler.routeForTest(request(const ForkPoint.afterMessage(messageId: "a1")));
    expect(created.status, 200);
    final session = Session.fromJson(jsonDecode(created.body ?? fail("missing body")) as Map<String, dynamic>);
    expect(session.forkedFrom, const SessionForkOrigin(sessionId: "s1", title: "Origin"));

    final refused = await handler.routeForTest(request(const ForkPoint.beforeMessage(messageId: "a1")));
    expect(refused.status, 409);
    final error = SessionBranchErrorResponse.fromJson(
      jsonDecode(refused.body ?? fail("missing body")) as Map<String, dynamic>,
    );
    expect(error.code, SessionBranchErrorCode.branchPointUnavailable);
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

class _FakeForkPlugin() extends FakeBridgePlugin implements SessionForkPluginApi {
  final Map<String, List<PluginMessageWithParts>> messagesByBackendId = {};
  final List<({String sessionId, String throughMessageId})> forks = [];
  List<PluginProjectActivitySummary> activeSummaries = [];
  Object? forkError;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => activeSummaries;

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async =>
      messagesByBackendId[sessionId] ?? const [];

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    await super.createSession(
      directory: directory,
      parentSessionId: parentSessionId,
      parts: parts,
      userVisibleText: userVisibleText,
      variant: variant,
      fastMode: fastMode,
      agent: agent,
      model: model,
    );
    return PluginSession(
      id: "backend-empty-fork",
      projectID: "/repo",
      directory: directory,
      parentID: null,
      title: null,
      time: null,
    );
  }

  @override
  Future<PluginSession> forkSession({required String sessionId, required String throughMessageId}) async {
    if (forkError case final error?) throw error;
    forks.add((sessionId: sessionId, throughMessageId: throughMessageId));
    return const PluginSession(
      id: "backend-fork",
      projectID: "/repo",
      directory: _worktree,
      parentID: null,
      title: null,
      time: null,
    );
  }
}

/// Serves the stored catalog session, as the real view does when no
/// continuation is pending.
final class const _CatalogViews({required final SessionRepository sessions}) implements SessionViewService {
  @override
  Future<Session> get({required String sessionId}) async =>
      await sessions.getCatalogSession(sessionId: sessionId) ?? (throw StateError("missing session $sessionId"));

  @override
  Future<Session> enrich({required Session session}) async => session;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Git's worktrees and branches, without running git.
class _FakeWorktreeGit() extends FakeGitCliApi {
  final worktrees = <String>{};
  final branches = <String>{};
  final added = <String>[];
  bool addSucceeds = true;

  /// The HEAD that archiving kept for a removed worktree.
  String? keptHead;

  @override
  Future<String?> resolveCommit({required String projectPath, required String ref}) async =>
      ref.startsWith("refs/sesori/") ? keptHead : null;

  @override
  Future<bool> isWorkTreeRoot({required String path}) async => worktrees.contains(path);

  @override
  Future<void> pruneWorktrees({required String projectPath}) async {}

  @override
  Future<bool> branchExists({required String projectPath, required String branchName}) async =>
      branches.contains(branchName);

  @override
  Future<bool> addWorktreeOnBranch({
    required String projectPath,
    required String worktreePath,
    required String branchName,
  }) async => _add(worktreePath: worktreePath, description: "$worktreePath on $branchName");

  @override
  Future<bool> addWorktreeOnNewBranch({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String startPoint,
  }) async => _add(worktreePath: worktreePath, description: "$worktreePath on new $branchName from $startPoint");

  @override
  Future<bool> createWorktree({
    required String projectPath,
    required String worktreePath,
    required String startPoint,
  }) async => _add(worktreePath: worktreePath, description: "$worktreePath detached at $startPoint");

  bool _add({required String worktreePath, required String description}) {
    if (!addSucceeds) return false;
    added.add(description);
    worktrees.add(worktreePath);
    return true;
  }
}

/// A disk holding [_git]'s worktrees and [otherEntries], folders that are no
/// worktree.
class _FakeWorktreeDisk({required final _FakeWorktreeGit _git}) implements FilesystemApi {
  final otherEntries = <String>{};

  @override
  FileSystemEntityType entityType({required String path}) =>
      _git.worktrees.contains(path) || otherEntries.contains(path)
      ? FileSystemEntityType.directory
      : FileSystemEntityType.notFound;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

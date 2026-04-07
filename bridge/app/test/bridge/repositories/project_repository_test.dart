import "package:drift/native.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("ProjectRepository", () {
    late AppDatabase db;
    late _FakeBridgePlugin plugin;
    late ProjectRepository repo;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeBridgePlugin();
      repo = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        db: db,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test("getProjects fetches plugin projects, persists each, filters hidden, sorts by updated desc", () async {
      plugin.projectsResult = const [
        PluginProject(id: "p1", name: "P1", time: PluginProjectTime(created: 0, updated: 100)),
        PluginProject(id: "p2", name: "P2", time: PluginProjectTime(created: 0, updated: 200)),
        PluginProject(id: "p3", name: "P3", time: PluginProjectTime(created: 0, updated: 300)),
      ];

      // Pre-hide p2 before the call — the repository must still persist it,
      // but it must not appear in the returned list.
      await db.projectsDao.hideProject(projectId: "p2");

      final result = await repo.getProjects();

      // (a) DB has all 3 rows (every plugin project is persisted regardless
      //     of hidden status — the FK target must always exist).
      final rows = await db.select(db.projectsTable).get();
      expect(
        rows.map((r) => r.projectId).toSet(),
        equals({"p1", "p2", "p3"}),
        reason: "every plugin project must be upserted into projects_table",
      );

      // (b) Returned list filters p2 out.
      expect(result, hasLength(2));

      // (c) Order is [p3, p1] — sorted by time.updated descending.
      expect(result.map((p) => p.id).toList(), equals(["p3", "p1"]));
    });

    test("getProjects rethrows PluginApiException when plugin throws", () async {
      plugin.getProjectsError = PluginApiException("/project", 500);

      await expectLater(
        () => repo.getProjects(),
        throwsA(isA<PluginApiException>()),
      );

      // Plugin failed before the transaction opened — no rows should be
      // present in the database.
      final rows = await db.select(db.projectsTable).get();
      expect(rows, isEmpty, reason: "no DB writes on plugin failure");
    });

    test("getProjects wraps inserts in a single transaction", () async {
      // Approach: subclass AppDatabase and increment a counter on each
      // `transaction()` invocation. A single transaction wrapping N inserts
      // => count == 1; one transaction per insert => count == N. This
      // observes the transaction boundary directly (see Task 5 notes).
      final trackingDb = _TxTrackingDatabase();
      try {
        final trackingPlugin = _FakeBridgePlugin()
          ..projectsResult = const [
            PluginProject(id: "p1"),
            PluginProject(id: "p2"),
            PluginProject(id: "p3"),
            PluginProject(id: "p4"),
          ];
        final trackingRepo = ProjectRepository(
          plugin: trackingPlugin,
          projectsDao: trackingDb.projectsDao,
          db: trackingDb,
        );

        await trackingRepo.getProjects();

        expect(
          trackingDb.transactionCount,
          equals(1),
          reason: "all N inserts must share a single transaction",
        );
        final rows = await trackingDb.select(trackingDb.projectsTable).get();
        expect(
          rows.map((r) => r.projectId).toSet(),
          equals({"p1", "p2", "p3", "p4"}),
        );
      } finally {
        await trackingDb.close();
      }
    });
  });
}

/// Minimal [BridgePlugin] fake that only implements the surface touched by
/// [ProjectRepository]. Every other member throws so accidental use is loud.
class _FakeBridgePlugin implements BridgePlugin {
  List<PluginProject> projectsResult = const [];
  Object? getProjectsError;

  @override
  Future<List<PluginProject>> getProjects() async {
    final err = getProjectsError;
    if (err != null) throw err;
    return projectsResult;
  }

  @override
  String get id => throw UnimplementedError();

  @override
  Stream<BridgeSseEvent> get events => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) => throw UnimplementedError();

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) => throw UnimplementedError();

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) => throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId) => throw UnimplementedError();

  @override
  Future<void> archiveSession({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) => throw UnimplementedError();

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() => throw UnimplementedError();

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) => throw UnimplementedError();

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<void> abortSession({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginAgent>> getAgents() => throw UnimplementedError();

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) => throw UnimplementedError();

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) => throw UnimplementedError();

  @override
  Future<void> rejectQuestion(String questionId) => throw UnimplementedError();

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) => throw UnimplementedError();

  @override
  Future<PluginProject> getProject(String projectId) => throw UnimplementedError();

  @override
  Future<bool> healthCheck() => throw UnimplementedError();

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) => throw UnimplementedError();

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => throw UnimplementedError();

  @override
  Future<void> dispose() => throw UnimplementedError();
}

/// [AppDatabase] variant that counts invocations of [transaction].
///
/// Used by the transaction-wrapping test to prove that [ProjectRepository]
/// opens exactly one transaction for N inserts instead of N transactions.
class _TxTrackingDatabase extends AppDatabase {
  _TxTrackingDatabase() : super(NativeDatabase.memory());

  int transactionCount = 0;

  @override
  Future<T> transaction<T>(Future<T> Function() action, {bool requireNew = false}) {
    transactionCount++;
    return super.transaction(action, requireNew: requireNew);
  }
}

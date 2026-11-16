import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/session_interruption_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/session_interruption_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/interrupted_turn_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/session_interruption_test_support.dart";
import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late SessionInterruptionRepository interruptions;
  late RecordingInterruptionMutations mutations;
  late TestChatHistory history;
  final earlierRun = DateTime.utc(2026, 11, 15, 10);
  final thisRun = DateTime.utc(2026, 11, 15, 11);

  setUp(() async {
    db = createTestDatabase();
    interruptions = SessionInterruptionRepository(dao: SessionInterruptionDao(database: db));
    mutations = RecordingInterruptionMutations();
    history = createTestChatHistory(interruptions: interruptions, mutations: mutations);
    for (final sessionId in ["idle", "missing", "busy", "empty"]) {
      await insertTestSessionInDirectory(
        db: db,
        sessionId: sessionId,
        pluginId: "codex",
        projectId: "p1",
        directory: "/repo",
      );
      await interruptions.markRunning(sessionId: sessionId, at: earlierRun);
    }
    for (final sessionId in ["idle", "missing", "busy"]) {
      for (final (index, createdAt) in [(1, 100), (2, 200)]) {
        await history.service.captureMessage(
          sessionId: sessionId,
          message: Message.user(
            invocation: null,
            handoff: null,
            promptId: null,
            id: "$sessionId-m$index",
            sessionID: sessionId,
            agent: null,
            time: MessageTime(created: createdAt, completed: null),
          ),
        );
      }
    }
  });

  tearDown(() => db.close());

  InterruptedTurnService service({required _Statuses sessions}) => InterruptedTurnService(
    interruptions: interruptions,
    sessions: sessions,
    chatHistory: history.service,
    mutations: mutations,
    clock: Clock.fixed(thisRun),
  );

  test("records the turns the plugin no longer runs and adopts the one it does", () async {
    final sessions = _Statuses(
      statuses: {
        "idle": const SessionStatus.idle(),
        "busy": const SessionStatus.busy(since: 1),
        "empty": const SessionStatus.idle(),
      },
    );

    await service(sessions: sessions).resolve(pluginId: "codex");

    final recorded = await interruptions.readMany(sessionIds: {"idle", "missing", "busy", "empty"});
    expect(
      {for (final MapEntry(:key, :value) in recorded.entries) key: (value.afterMessageId, value.acknowledged)},
      {"idle": ("idle-m2", false), "missing": ("missing-m2", false)},
    );
    expect(mutations.updated, unorderedEquals(["idle", "missing"]));
    // The busy turn now belongs to this run; no row is left over.
    expect(await interruptions.readLeftovers(pluginId: "codex", startedBefore: thisRun), isEmpty);
    final running = await interruptions.readLeftovers(
      pluginId: "codex",
      startedBefore: thisRun.add(const Duration(seconds: 1)),
    );
    expect([for (final row in running) (row.sessionId, row.startedAt)], [("busy", thisRun)]);
  });

  test("keeps every row when the plugin's statuses cannot be read", () async {
    await service(sessions: _Statuses(statuses: null)).resolve(pluginId: "codex");

    expect(await interruptions.readMany(sessionIds: {"idle", "missing", "busy", "empty"}), isEmpty);
    expect(await interruptions.readLeftovers(pluginId: "codex", startedBefore: thisRun), hasLength(4));
    expect(mutations.updated, isEmpty);
  });
}

/// The plugin's statuses, or a failed read when null.
final class _Statuses({required final Map<String, SessionStatus>? statuses}) implements SessionRepository {
  @override
  Future<Map<String, SessionStatus>> getPluginSessionStatuses({required String pluginId}) async =>
      statuses ?? (throw StateError("plugin unavailable"));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

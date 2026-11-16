import "package:sesori_bridge/src/api/database/daos/session_interruption_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/session_running_turn_record.dart";
import "package:sesori_bridge/src/repositories/session_interruption_repository.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  late AppDatabase db;
  late SessionInterruptionRepository repository;
  final earlierRun = DateTime.utc(2026, 11, 15, 10);
  final thisRun = DateTime.utc(2026, 11, 15, 11);

  setUp(() async {
    db = createTestDatabase();
    repository = SessionInterruptionRepository(dao: SessionInterruptionDao(database: db));
    for (final (sessionId, pluginId) in [("s1", "codex"), ("s2", "codex"), ("other", "claude")]) {
      await insertTestSessionInDirectory(
        db: db,
        sessionId: sessionId,
        pluginId: pluginId,
        projectId: "p1",
        directory: "/repo",
      );
    }
  });

  tearDown(() => db.close());

  Future<SessionRunningTurnRecord> leftover({required String sessionId}) async {
    await repository.markRunning(sessionId: sessionId, at: earlierRun);
    final leftovers = await repository.readLeftovers(pluginId: "codex", startedBefore: thisRun);
    return leftovers.singleWhere((row) => row.sessionId == sessionId);
  }

  test("reads the plugin's rows an earlier run wrote", () async {
    await repository.markRunning(sessionId: "s1", at: earlierRun);
    await repository.markRunning(sessionId: "s2", at: thisRun);
    await repository.markRunning(sessionId: "other", at: earlierRun);

    final leftovers = await repository.readLeftovers(pluginId: "codex", startedBefore: thisRun);

    expect([for (final row in leftovers) (row.sessionId, row.startedAt)], [("s1", earlierRun)]);
  });

  test("converts a leftover into an unacknowledged interruption and drops its row", () async {
    final row = await leftover(sessionId: "s1");

    expect(await repository.convertLeftover(leftover: row, afterMessageId: "m2"), isTrue);

    final interruption = (await repository.readMany(sessionIds: {"s1"}))["s1"];
    expect((interruption?.afterMessageId, interruption?.acknowledged), ("m2", false));
    expect(await repository.readLeftovers(pluginId: "codex", startedBefore: thisRun), isEmpty);
  });

  test("a leftover with no stored message only loses its row", () async {
    final row = await leftover(sessionId: "s1");

    expect(await repository.convertLeftover(leftover: row, afterMessageId: null), isFalse);

    expect(await repository.readMany(sessionIds: {"s1"}), isEmpty);
    expect(await repository.readLeftovers(pluginId: "codex", startedBefore: thisRun), isEmpty);
  });

  test("adopting a leftover restamps it into this run", () async {
    final row = await leftover(sessionId: "s1");

    expect(await repository.adoptLeftover(leftover: row, now: thisRun), isTrue);

    expect(await repository.readLeftovers(pluginId: "codex", startedBefore: thisRun), isEmpty);
    expect(await repository.readMany(sessionIds: {"s1"}), isEmpty);
  });

  test("a turn of this run that started after the leftover was read is left alone", () async {
    final row = await leftover(sessionId: "s1");
    // The running-turn listener sees a new turn start before the resolution
    // writes.
    await repository.markRunning(sessionId: "s1", at: thisRun.add(const Duration(seconds: 1)));

    expect(await repository.convertLeftover(leftover: row, afterMessageId: "m2"), isFalse);
    expect(await repository.adoptLeftover(leftover: row, now: thisRun), isFalse);

    expect(await repository.readMany(sessionIds: {"s1"}), isEmpty);
    final stillRunning = await repository.readLeftovers(
      pluginId: "codex",
      startedBefore: thisRun.add(const Duration(minutes: 1)),
    );
    expect([for (final row in stillRunning) row.startedAt], [thisRun.add(const Duration(seconds: 1))]);
  });

  test("acknowledging flips an interruption once", () async {
    await repository.convertLeftover(
      leftover: await leftover(sessionId: "s1"),
      afterMessageId: "m2",
    );

    expect(await repository.acknowledge(sessionId: "s1"), isTrue);
    expect(await repository.acknowledge(sessionId: "s1"), isFalse);
    expect(await repository.acknowledge(sessionId: "s2"), isFalse);
    expect((await repository.readMany(sessionIds: {"s1"}))["s1"]?.acknowledged, isTrue);
  });

  test("re-anchoring follows the anchor's replacement only", () async {
    await repository.convertLeftover(
      leftover: await leftover(sessionId: "s1"),
      afterMessageId: "live",
    );

    expect(await repository.reanchor(sessionId: "s1", replacementIds: const {"other": "x"}), isFalse);
    expect(await repository.reanchor(sessionId: "s1", replacementIds: const {"live": "replay"}), isTrue);
    expect(await repository.reanchor(sessionId: "s2", replacementIds: const {"live": "replay"}), isFalse);
    expect((await repository.readMany(sessionIds: {"s1"}))["s1"]?.afterMessageId, "replay");
  });
}

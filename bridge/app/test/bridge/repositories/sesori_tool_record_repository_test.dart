import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/sesori_tool_record_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/sesori_tool_record_repository.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

const _monitor = SesoriToolGroupId("pr_monitor");
const _other = SesoriToolGroupId("other");

void main() {
  late AppDatabase db;
  late SesoriToolRecordRepository records;

  Future<void> insertSession({required String sessionId}) => insertTestSession(
    db: db,
    sessionId: sessionId,
    backendSessionId: "backend-$sessionId",
    pluginId: "codex",
    projectId: "/repo",
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    baseBranch: null,
    baseCommit: null,
    agent: null,
    agentModel: null,
  );

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    records = SesoriToolRecordRepository(
      dao: SesoriToolRecordDao(database: db),
      clock: Clock.fixed(DateTime.utc(2026, 11, 25)),
    );
    await insertSession(sessionId: "s1");
    await insertSession(sessionId: "s2");
  });

  test("session records round-trip, replace by key and stay within their group", () async {
    await records.putSessionRecord(groupId: _monitor, sessionId: "s1", key: "a/b#1", value: {"n": 1});
    await records.putSessionRecord(groupId: _monitor, sessionId: "s1", key: "a/b#1", value: {"n": 2});
    await records.putSessionRecord(groupId: _monitor, sessionId: "s2", key: "a/b#1", value: {"n": 3});
    await records.putSessionRecord(groupId: _other, sessionId: "s1", key: "a/b#1", value: {"n": 4});

    expect(await records.getSessionRecord(groupId: _monitor, sessionId: "s1", key: "a/b#1"), {"n": 2});
    expect(await records.listRecordsOfSession(groupId: _monitor, sessionId: "s1"), {
      "a/b#1": {"n": 2},
    });
    // Maps, so the values compare by content.
    expect(
      [
        for (final record in await records.listSessionRecords(groupId: _monitor))
          {"sessionId": record.sessionId, "key": record.key, "value": record.value},
      ],
      [
        {
          "sessionId": "s1",
          "key": "a/b#1",
          "value": {"n": 2},
        },
        {
          "sessionId": "s2",
          "key": "a/b#1",
          "value": {"n": 3},
        },
      ],
    );

    expect(await records.deleteSessionRecord(groupId: _monitor, sessionId: "s1", key: "a/b#1"), isTrue);
    expect(await records.deleteSessionRecord(groupId: _monitor, sessionId: "s1", key: "a/b#1"), isFalse);
    expect(await records.getSessionRecord(groupId: _monitor, sessionId: "s1", key: "a/b#1"), isNull);
    expect(await records.getSessionRecord(groupId: _other, sessionId: "s1", key: "a/b#1"), {"n": 4});
  });

  test("bridge records round-trip, replace by key and stay within their group", () async {
    await records.putRecord(groupId: _monitor, key: "config", value: {"autoMerge": false});
    await records.putRecord(groupId: _monitor, key: "config", value: {"autoMerge": true});
    await records.putRecord(groupId: _other, key: "config", value: {"x": 1});

    expect(await records.getRecord(groupId: _monitor, key: "config"), {"autoMerge": true});
    expect(await records.listRecords(groupId: _monitor), {
      "config": {"autoMerge": true},
    });
    expect(await records.deleteRecord(groupId: _monitor, key: "config"), isTrue);
    expect(await records.deleteRecord(groupId: _monitor, key: "config"), isFalse);
    expect(await records.listRecords(groupId: _other), {
      "config": {"x": 1},
    });
  });

  test("deleting a session deletes its records with it", () async {
    await records.putSessionRecord(groupId: _monitor, sessionId: "s1", key: "a/b#1", value: {"n": 1});
    await records.putSessionRecord(groupId: _monitor, sessionId: "s2", key: "a/b#2", value: {"n": 2});

    await db.customStatement("DELETE FROM sessions_table WHERE session_id = ?", ["s1"]);

    expect([for (final record in await records.listSessionRecords(groupId: _monitor)) record.sessionId], ["s2"]);
  });

  test("a record for a session that is not stored is refused", () async {
    await expectLater(
      records.putSessionRecord(groupId: _monitor, sessionId: "gone", key: "a/b#1", value: {"n": 1}),
      throwsA(anything),
    );
  });
}

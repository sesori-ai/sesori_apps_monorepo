import "dart:math";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/api/database/daos/sesori_tool_record_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/agent_approval_repository.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/models/session_notice.dart";
import "package:sesori_bridge/src/repositories/sesori_tool_record_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/server/host/bridge_sesori_tool_host_impl.dart";
import "package:sesori_bridge/src/server/host/bridge_sesori_tool_store_impl.dart";
import "package:sesori_bridge/src/services/session_notice_service.dart";
import "package:sesori_bridge/src/services/tool_group_approval_service.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/fakes/wake_up_command_fakes.dart";
import "../../helpers/in_memory_bridge_settings_api.dart";
import "../../helpers/test_database.dart";

const _monitor = SesoriToolGroupId("pr_monitor");
const _other = SesoriToolGroupId("other");

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late BridgeSettingsRepository settings;
  late _Notices notices;
  late AgentApprovalRepository approvals;

  BridgeSesoriToolHostImpl hostFor({required SesoriToolGroupId groupId}) => BridgeSesoriToolHostImpl(
    groupId: groupId,
    store: BridgeSesoriToolStoreImpl(
      groupId: groupId,
      records: SesoriToolRecordRepository(
        dao: SesoriToolRecordDao(database: db),
        clock: const Clock(),
      ),
    ),
    notices: notices,
    sessions: sessions,
    settings: settings,
    approvals: ToolGroupApprovalService(approvals: approvals, sessions: sessions, autoApproval: FakeAutoApproval()),
  );

  Future<void> insertSession({required String sessionId, required String? worktreePath}) => insertTestSession(
    db: db,
    sessionId: sessionId,
    backendSessionId: "backend-$sessionId",
    pluginId: "fake",
    projectId: "/repo",
    isDedicated: worktreePath != null,
    createdAt: 1,
    worktreePath: worktreePath,
    baseBranch: null,
    baseCommit: null,
    agent: null,
    agentModel: null,
  );

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    sessions = singlePluginSessionRepository(
      plugin: FakeBridgePlugin(),
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    settings = BridgeSettingsRepository(defaultEditorApi: null, api: InMemoryBridgeSettingsApi(config: "{}"));
    await settings.loadSettings();
    addTearDown(settings.dispose);
    notices = _Notices();
    approvals = AgentApprovalRepository(random: Random(1));
    addTearDown(approvals.dispose);
    await insertSession(sessionId: "root", worktreePath: null);
  });

  group("deliverNotice", () {
    test("hands the notice and its claim to the session's delivery", () async {
      final host = hostFor(groupId: _monitor);
      var claims = 0;

      final outcome = await host.deliverNotice(
        sessionId: "root",
        summary: "PR monitor: a/b#1 — CI failing",
        guidance: "The report.",
        timing: SesoriToolNoticeTiming.derived,
        claim: () async {
          claims++;
          await host.store.putSessionRecord(sessionId: "root", key: "a/b#1", value: {"reported": true});
          return true;
        },
      );

      expect(outcome, SesoriToolNoticeOutcome.sent);
      expect(claims, 1);
      final sent = notices.delivered.single;
      expect(sent.sessionId, "root");
      expect(sent.timing, SessionNoticeTiming.derived);
      expect(sent.notice.summary, "PR monitor: a/b#1 — CI failing");
      expect(sent.notice.guidance, "The report.");
      expect(sent.notice.pageRequestId, isNull);
      expect(await host.store.getSessionRecord(sessionId: "root", key: "a/b#1"), {"reported": true});
    });

    test("a lost claim sends nothing", () async {
      final outcome = await hostFor(groupId: _monitor).deliverNotice(
        sessionId: "root",
        summary: "s",
        guidance: "g",
        timing: SesoriToolNoticeTiming.afterTurn,
        claim: () async => false,
      );

      expect(outcome, SesoriToolNoticeOutcome.claimLost);
      expect(notices.delivered, isEmpty);
    });

    test("reports a skipped and a dropped delivery as such", () async {
      final host = hostFor(groupId: _monitor);
      for (final (delivered, expected) in [
        (SessionNoticeOutcome.skippedInactive, SesoriToolNoticeOutcome.skippedInactive),
        (SessionNoticeOutcome.dropped, SesoriToolNoticeOutcome.dropped),
      ]) {
        notices.forced = delivered;
        expect(
          await host.deliverNotice(
            sessionId: "root",
            summary: "s",
            guidance: "g",
            timing: SesoriToolNoticeTiming.afterTurn,
            claim: null,
          ),
          expected,
        );
      }
      expect(notices.timings, everyElement(SessionNoticeTiming.afterTurn));
    });
  });

  test("sessions resolves each stored session's root, folder and archive state", () async {
    await insertSession(sessionId: "child", worktreePath: "/worktrees/child");
    await db.customStatement("UPDATE sessions_table SET parent_session_id = 'root' WHERE session_id = 'child'");
    await insertSession(sessionId: "archived", worktreePath: null);
    await db.customStatement("UPDATE sessions_table SET archived_at = 300 WHERE session_id = 'archived'");

    final found = await hostFor(groupId: _monitor).sessions(sessionIds: {"root", "child", "archived", "gone"});

    expect(found.keys, unorderedEquals(["root", "child", "archived"]));
    expect(found["root"]?.rootSessionId, "root");
    expect(found["root"]?.workingDirectory, "/repo");
    expect(found["root"]?.archived, isFalse);
    expect(found["child"]?.rootSessionId, "root");
    expect(found["child"]?.workingDirectory, "/worktrees/child");
    expect(found["archived"]?.archived, isTrue);
  });

  test("enabled follows the group's toggle and the master switch", () async {
    final host = hostFor(groupId: _monitor);
    final changes = <bool>[];
    final subscription = host.enabledChanges.listen(changes.add);
    addTearDown(subscription.cancel);
    expect(host.enabled, isTrue);

    await settings.updateToolGroup(id: _other, enabled: false);
    await settings.updateToolGroup(id: _monitor, enabled: false);
    expect(host.enabled, isFalse);
    await settings.updateToolGroup(id: _monitor, enabled: true);
    await settings.updateAgentTools(enabled: false);
    expect(host.enabled, isFalse);
    await pumpEventQueue();

    expect(changes, [false, true, false], reason: "the other group's toggle is not this group's change");
  });

  test("each group's store sees only its own records", () async {
    final monitor = hostFor(groupId: _monitor);
    final other = hostFor(groupId: _other);

    await monitor.store.putSessionRecord(sessionId: "root", key: "k", value: {"group": "monitor"});
    await monitor.store.putRecord(key: "config", value: {"group": "monitor"});
    await other.store.putRecord(key: "config", value: {"group": "other"});

    expect(await other.store.getSessionRecord(sessionId: "root", key: "k"), isNull);
    expect(await other.store.listSessionRecords(), isEmpty);
    expect(await monitor.store.listRecordsOfSession(sessionId: "root"), {
      "k": {"group": "monitor"},
    });
    expect(await monitor.store.getRecord(key: "config"), {"group": "monitor"});
    expect(await other.store.listRecords(), {
      "config": {"group": "other"},
    });
    expect(await other.store.deleteSessionRecord(sessionId: "root", key: "k"), isFalse);
    expect(await monitor.store.deleteSessionRecord(sessionId: "root", key: "k"), isTrue);
    expect(await monitor.store.deleteRecord(key: "config"), isTrue);
  });
}

/// Runs the claim as the real delivery does right before its send, unless
/// [forced] says the delivery ended before that.
class _Notices() implements SessionNoticeService {
  final List<({String sessionId, SessionNotice notice, SessionNoticeTiming timing})> delivered = [];
  final List<SessionNoticeTiming> timings = [];
  SessionNoticeOutcome? forced;

  @override
  Future<SessionNoticeOutcome> deliver({
    required String sessionId,
    required SessionNotice notice,
    required SessionNoticeTiming timing,
    required Future<bool> Function()? claim,
  }) async {
    timings.add(timing);
    if (forced case final outcome?) return outcome;
    if (claim != null && !await claim()) return SessionNoticeOutcome.claimLost;
    delivered.add((sessionId: sessionId, notice: notice, timing: timing));
    return SessionNoticeOutcome.sent;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

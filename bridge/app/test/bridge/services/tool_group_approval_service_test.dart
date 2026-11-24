import "dart:math";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/agent_approval_repository.dart";
import "package:sesori_bridge/src/repositories/models/agent_approval.dart";
import "package:sesori_bridge/src/repositories/models/agent_approval_change.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/services/tool_group_approval_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/fakes/wake_up_command_fakes.dart";
import "../../helpers/test_database.dart";

const _monitor = SesoriToolGroupId("pr_monitor");

void main() {
  late AppDatabase db;
  late AgentApprovalRepository approvals;
  late FakeAutoApproval autoApproval;
  late ToolGroupApprovalService service;
  late List<PendingPermission> asked;

  Future<void> insertSession({required String sessionId, required String? parentSessionId}) async {
    await insertTestSession(
      db: db,
      sessionId: sessionId,
      backendSessionId: "backend-$sessionId",
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
    if (parentSessionId != null) {
      await db.customStatement("UPDATE sessions_table SET parent_session_id = ? WHERE session_id = ?", [
        parentSessionId,
        sessionId,
      ]);
    }
  }

  Future<SesoriToolApprovalOutcome> request({required String sessionId}) => service.request(
    groupId: _monitor,
    sessionId: sessionId,
    title: "Sesori: PR monitor auto-merge",
    body: "Turn auto-merge on for **every repository**?",
  );

  /// Answers [permission] as the reply route does: the repository hands
  /// back the change, then the service settles it.
  void answer({required PendingPermission permission, required PermissionReply reply}) {
    final approval = approvals.take(requestId: permission.id, reply: reply) ?? fail("not pending");
    expect(approval.change, isA<ToolGroupAgentChange>().having((change) => change.groupId, "groupId", _monitor));
    service.settle(requestId: permission.id, reply: reply);
  }

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    approvals = AgentApprovalRepository(random: Random(1));
    addTearDown(approvals.dispose);
    asked = [];
    final subscription = approvals.events.listen((event) {
      if (event case AgentApprovalAsked(:final permission)) asked.add(permission);
    });
    addTearDown(subscription.cancel);
    autoApproval = FakeAutoApproval();
    service = ToolGroupApprovalService(
      approvals: approvals,
      sessions: singlePluginSessionRepository(
        plugin: FakeBridgePlugin(),
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        unseenCalculator: const SessionUnseenCalculator(),
      ),
      autoApproval: autoApproval,
    );
    await insertSession(sessionId: "root", parentSessionId: null);
    await insertSession(sessionId: "child", parentSessionId: "root");
  });

  test("Allow shows the card and completes the request as allowed", () async {
    final outcome = request(sessionId: "root");
    await pumpEventQueue();

    final permission = asked.single;
    expect(permission.tool, "Sesori: PR monitor auto-merge");
    expect(permission.description, "Turn auto-merge on for **every repository**?");
    expect(permission.sessionID, "root");
    expect(permission.displaySessionId, isNull);
    expect(permission.allowAlways, isFalse);

    answer(permission: permission, reply: PermissionReply.once);
    expect(await outcome, SesoriToolApprovalOutcome.allowed);
    expect(approvals.pendingPermissions(sessionId: "root"), isEmpty);
  });

  test("Reject completes the request as rejected", () async {
    final outcome = request(sessionId: "root");
    await pumpEventQueue();

    answer(permission: asked.single, reply: PermissionReply.reject);
    expect(await outcome, SesoriToolApprovalOutcome.rejected);
  });

  test("a sub-agent's request shows on its root session", () async {
    final outcome = request(sessionId: "child");
    await pumpEventQueue();

    final permission = asked.single;
    expect(permission.sessionID, "child");
    expect(permission.displaySessionId, "root");
    answer(permission: permission, reply: PermissionReply.once);
    expect(await outcome, SesoriToolApprovalOutcome.allowed);
  });

  test("a bridge stop drops every open request", () async {
    final first = request(sessionId: "root");
    final second = request(sessionId: "child");
    await pumpEventQueue();
    expect(asked, hasLength(2));

    service.dispose();

    expect(await first, SesoriToolApprovalOutcome.dropped);
    expect(await second, SesoriToolApprovalOutcome.dropped);
  });

  test("Approve everything allows at once with no card", () async {
    autoApproval.yoloSessionIds.addAll({"root", "child"});

    expect(await request(sessionId: "root"), SesoriToolApprovalOutcome.allowed);
    expect(await request(sessionId: "child"), SesoriToolApprovalOutcome.allowed);
    await pumpEventQueue();
    expect(asked, isEmpty);
  });

  test("Approve everything on the sub-agent alone still asks on the root", () async {
    autoApproval.yoloSessionIds.add("child");

    final outcome = request(sessionId: "child");
    await pumpEventQueue();
    expect(asked.single.displaySessionId, "root");
    answer(permission: asked.single, reply: PermissionReply.reject);
    expect(await outcome, SesoriToolApprovalOutcome.rejected);
  });

  test("a session that is not stored is dropped without a card", () async {
    expect(await request(sessionId: "gone"), SesoriToolApprovalOutcome.dropped);
    await pumpEventQueue();
    expect(asked, isEmpty);
  });
}

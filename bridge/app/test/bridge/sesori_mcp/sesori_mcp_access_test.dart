import "dart:math";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/models/sesori_mcp_grant.dart";
import "package:sesori_bridge/src/repositories/models/sesori_tool_group_ids.dart";
import "package:sesori_bridge/src/repositories/sesori_mcp_grant_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/server/host/bridge_sesori_mcp_access_impl.dart";
import "package:sesori_bridge/src/services/sesori_mcp_access_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolCaller, SesoriToolGroupId;
import "package:test/test.dart";

import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/skill_bundle_test_support.dart";
import "../../helpers/test_database.dart";

void main() {
  final url = Uri.parse("http://127.0.0.1:4100/mcp");
  const tasksOnly = {SesoriToolGroupIds.tasks};

  group("SesoriMcpGrantRepository", () {
    test("mints distinct unguessable tokens, unbound until bound", () {
      final grants = SesoriMcpGrantRepository(random: Random.secure());

      final first = grants.mint(pluginId: "codex", groups: tasksOnly);
      final second = grants.mint(pluginId: "codex", groups: tasksOnly);

      expect(first, isNot(second));
      // 32 random bytes in unpadded base64url.
      expect(first, matches(RegExp(r"^[A-Za-z0-9_-]{43}$")));
      expect(
        grants.lookup(token: first),
        isA<SesoriMcpGrantUnbound>().having((grant) => grant.pluginId, "pluginId", "codex"),
      );

      grants.bind(token: first, backendSessionId: "thread-1");

      expect(
        grants.lookup(token: first),
        isA<SesoriMcpGrantBound>()
            .having((grant) => grant.pluginId, "pluginId", "codex")
            .having((grant) => grant.backendSessionId, "backendSessionId", "thread-1")
            .having((grant) => grant.groups, "groups", tasksOnly),
      );
      expect(grants.lookup(token: second), isA<SesoriMcpGrantUnbound>());
    });

    test("refuses a token it never minted, including one from before a restart", () {
      final beforeRestart = SesoriMcpGrantRepository(random: Random.secure());
      final token = beforeRestart.mint(pluginId: "codex", groups: tasksOnly);
      final afterRestart = SesoriMcpGrantRepository(random: Random.secure());

      expect(afterRestart.lookup(token: token), isNull);
      expect(afterRestart.lookup(token: "made-up"), isNull);
      expect(() => afterRestart.bind(token: token, backendSessionId: "thread-1"), throwsStateError);
    });
  });

  group("BridgeSesoriMcpAccessImpl", () {
    test("mints a launch with this bridge's URL and a fresh token", () {
      final grants = SesoriMcpGrantRepository(random: Random.secure());
      final access = BridgeSesoriMcpAccessImpl(
        pluginId: "codex",
        url: url,
        grants: grants,
        enabledToolGroups: () => tasksOnly,
        skillBundles: temporarySkillBundleStorage(),
      );

      final launch = access.mint() ?? fail("a group is on, so a launch is minted");

      final SesoriMcpLaunch(:serverName, url: launchUrl, :token) = launch;
      expect(serverName, sesoriMcpServerName);
      expect(launchUrl, url.toString());
      expect(
        grants.lookup(token: token),
        isA<SesoriMcpGrantUnbound>().having((grant) => grant.groups, "groups", tasksOnly),
      );
      expect(launch.toString(), isNot(contains(token)));

      access.bind(launch: launch, backendSessionId: "thread-1");

      expect(grants.lookup(token: token), isA<SesoriMcpGrantBound>());
    });

    test("mints nothing while no tool group is on", () {
      var enabled = <SesoriToolGroupId>{};
      final access = BridgeSesoriMcpAccessImpl(
        pluginId: "codex",
        url: url,
        grants: SesoriMcpGrantRepository(random: Random.secure()),
        enabledToolGroups: () => enabled,
        skillBundles: temporarySkillBundleStorage(),
      );

      expect(access.mint(), isNull);
      enabled = tasksOnly;
      expect(access.mint(), isNotNull);
    });
  });

  group("SesoriMcpAccessService", () {
    late AppDatabase db;
    late SesoriMcpGrantRepository grants;
    late SesoriMcpAccessService service;

    setUp(() async {
      db = createTestDatabase();
      addTearDown(db.close);
      final plugin = FakeBridgePlugin();
      grants = SesoriMcpGrantRepository(random: Random.secure());
      service = SesoriMcpAccessService(
        grants: grants,
        sessions: singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          unseenCalculator: const SessionUnseenCalculator(),
        ),
      );
      await insertTestSession(
        db: db,
        sessionId: "s1",
        backendSessionId: "backend-s1",
        pluginId: plugin.id,
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

    test("resolves a bound token to the Sesori session holding its backend session", () async {
      final token = grants.mint(pluginId: "fake", groups: tasksOnly);
      grants.bind(token: token, backendSessionId: "backend-s1");

      expect(service.grantedGroups(token: token), tasksOnly);
      expect(
        await service.resolve(token: token),
        isA<SesoriToolCaller>().having((caller) => caller.sessionId, "sessionId", "s1"),
      );
    });

    test("resolves no caller while unbound, for an unknown backend session or another plugin", () async {
      final unbound = grants.mint(pluginId: "fake", groups: tasksOnly);
      final unknownSession = grants.mint(pluginId: "fake", groups: tasksOnly);
      grants.bind(token: unknownSession, backendSessionId: "backend-missing");
      final otherPlugin = grants.mint(pluginId: "codex", groups: tasksOnly);
      grants.bind(token: otherPlugin, backendSessionId: "backend-s1");

      expect(await service.resolve(token: unbound), isNull);
      expect(await service.resolve(token: unknownSession), isNull);
      expect(await service.resolve(token: otherPlugin), isNull);
      expect(service.grantedGroups(token: "made-up"), isNull);
      expect(await service.resolve(token: "made-up"), isNull);
    });
  });
}

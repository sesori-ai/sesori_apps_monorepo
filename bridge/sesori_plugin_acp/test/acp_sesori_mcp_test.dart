import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Every session the live process activates carries Sesori's MCP server, one
/// launch per session; probes and the short-lived history process carry none.
void main() {
  group("AcpPlugin Sesori MCP server", () {
    late List<FakeAcpProcess> fakes;
    late RecordingSesoriMcpAccess access;
    late AcpPlugin plugin;

    AcpPlugin buildPlugin({required bool replaysOnLiveProcess}) {
      final configurationTracker = AcpSessionConfigurationTracker();
      final childSessionTracker = AcpChildSessionTracker();
      return _SesoriMcpTestPlugin(
        replaysOnLiveProcess: replaysOnLiveProcess,
        id: "acp",
        agentDisplayName: "ACP",
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "agent", args: ["acp"]),
        launchDirectory: "/repo",
        eventMapper: AcpEventMapper(
          launchDirectory: "/repo",
          pluginId: "acp",
          configurationTracker: configurationTracker,
          childSessions: childSessionTracker,
        ),
        childSessionTracker: childSessionTracker,
        commandTracker: AcpCommandTracker(selectionCommands: const {}),
        processFactory: (_) async {
          final fake = FakeAcpProcess();
          fakes.add(fake);
          return fake;
        },
        sesoriMcp: access,
      );
    }

    setUp(() {
      fakes = [];
      access = RecordingSesoriMcpAccess(enabled: true);
    });

    tearDown(() async {
      await plugin.dispose();
      for (final fake in fakes) {
        await fake.close();
      }
    });

    Future<Map<String, dynamic>> waitForFrame(FakeAcpProcess Function() fake, String method) async {
      for (var i = 0; i < 400; i++) {
        if (fakes.isNotEmpty) {
          final matches = fake().written.where((f) => f["method"] == method);
          if (matches.isNotEmpty) return matches.last;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Future<Map<String, dynamic>> respond(
      FakeAcpProcess Function() fake,
      String method,
      Map<String, dynamic> result,
    ) async {
      final frame = await waitForFrame(fake, method);
      fake().emit({"jsonrpc": "2.0", "id": frame["id"], "result": result});
      await Future<void>.delayed(Duration.zero);
      return (frame["params"] as Map).cast<String, dynamic>();
    }

    FakeAcpProcess live() => fakes.first;

    Future<void> connect() async {
      final connecting = plugin.ensureConnected();
      await respond(live, "initialize", {
        "protocolVersion": 1,
        "agentCapabilities": {"loadSession": true},
        "authMethods": <Object?>[],
      });
      expect(await connecting, isTrue);
    }

    Future<Map<String, dynamic>> create(String sessionId) async {
      final creating = plugin.createSession(
        origin: PluginPromptOrigin.user,
        fastMode: false,
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      await waitForFrame(live, "session/new");
      // The token is bound only once the agent has named the session.
      expect(access.binds, isEmpty);
      final params = await respond(live, "session/new", {"sessionId": sessionId});
      await creating;
      return params;
    }

    Map<String, dynamic> httpServer(String token) => {
      "type": "http",
      "name": sesoriMcpServerName,
      "url": RecordingSesoriMcpAccess.url,
      "headers": [
        {"name": "Authorization", "value": "Bearer $token"},
      ],
    };

    test("session/new carries the server with its token in a header, bound to the new session", () async {
      plugin = buildPlugin(replaysOnLiveProcess: false);
      await connect();

      final params = await create("s1");

      expect(params["mcpServers"], [httpServer("token-1")]);
      expect(params["_meta"], {"skills": RecordingSesoriMcpAccess.skills.pluginRoot});
      expect(access.binds, [("token-1", "s1")]);
    });

    test("a live-process history reload re-sends the session's own launch", () async {
      plugin = buildPlugin(replaysOnLiveProcess: true);
      await connect();
      await create("s1");

      final loading = plugin.getSessionMessages("s1");
      final params = await respond(live, "session/load", {"sessionId": "s1"});
      await loading;

      expect(params["mcpServers"], [httpServer("token-1")]);
      expect(access.minted, 1);
    });

    test("a prior-run session is loaded with a launch bound to it", () async {
      plugin = buildPlugin(replaysOnLiveProcess: false);
      await connect();

      final sending = plugin.sendPrompt(
        origin: PluginPromptOrigin.user,
        fastMode: false,
        promptId: "prompt-1",
        sessionId: "old-1",
        parts: const [PluginPromptPart.text(text: "hi")],
        variant: null,
        agent: null,
        model: null,
      );
      final params = await respond(live, "session/load", {"sessionId": "old-1"});
      await respond(live, "session/prompt", {"stopReason": "end_turn"});
      await sending;

      expect(params["mcpServers"], [httpServer("token-1")]);
      expect(params["_meta"], {"skills": RecordingSesoriMcpAccess.skills.pluginRoot});
      expect(access.binds, [("token-1", "old-1")]);
    });

    test("the short-lived history process gets no server", () async {
      plugin = buildPlugin(replaysOnLiveProcess: false);
      await connect();

      final loading = plugin.getSessionMessages("old-1");
      for (var i = 0; i < 400 && fakes.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      FakeAcpProcess replay() => fakes.last;
      await respond(replay, "initialize", {
        "protocolVersion": 1,
        "agentCapabilities": {"loadSession": true},
        "authMethods": <Object?>[],
      });
      final params = await respond(replay, "session/load", {"sessionId": "old-1"});
      await loading;

      expect(fakes, hasLength(2));
      expect(params["mcpServers"], isEmpty);
      expect(params, isNot(contains("_meta")));
      expect(access.minted, 0);
    });

    test("with agent tools off, sessions get no server and nothing is bound", () async {
      access.enabled = false;
      plugin = buildPlugin(replaysOnLiveProcess: false);
      await connect();

      final params = await create("s1");

      expect(params["mcpServers"], isEmpty);
      expect(params, isNot(contains("_meta")));
      expect(access.binds, isEmpty);
    });
  });
}

class _SesoriMcpTestPlugin({
  required final bool replaysOnLiveProcess,
  required super.id,
  required super.agentDisplayName,
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.childSessionTracker,
  required super.commandTracker,
  required super.processFactory,
  required super.sesoriMcp,
}) extends TestAcpPlugin {
  @override
  bool get replaysResidentHistoryOnLiveProcess => replaysOnLiveProcess;

  @override
  Map<String, dynamic>? sessionActivationMeta({required SesoriSkillBundle? skills}) => switch (skills) {
    final skills? => {"skills": skills.pluginRoot},
    null => null,
  };
}

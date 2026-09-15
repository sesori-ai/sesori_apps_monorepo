import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ACP HTTP MCP integration", () {
    late FakeAcpProcess fake;
    late TestAcpPlugin plugin;
    late _AgentToolHost tools;
    AcpBridgePlugin? wrapper;

    setUp(() {
      fake = FakeAcpProcess();
      plugin = composeTestAcpPlugin(
        processFactory: (_) async => fake,
        permitsDeviceCanvasHttpMcp: true,
      );
      tools = _AgentToolHost();
    });

    tearDown(() async {
      tools.releaseBlockedRevoke();
      final activeWrapper = wrapper;
      if (activeWrapper == null) {
        await plugin.dispose();
      } else {
        await activeWrapper.shutdown(budget: null);
      }
      await fake.close();
    });

    Future<Map<String, dynamic>> waitForFrame(String method, {int count = 1}) async {
      for (var i = 0; i < 400; i++) {
        final frames = fake.written.where((frame) => frame["method"] == method).toList();
        if (frames.length >= count) return frames[count - 1];
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote frame $count for '$method'");
    }

    Future<void> start({
      required bool http,
      bool? load,
      bool resume = false,
      Object? resumeCapability,
      bool close = false,
    }) async {
      final supportsLoad = load ?? (http && !resume && resumeCapability == null);
      final starting = AcpBridgePlugin.start(
        plugin: plugin,
        host: _Host(tools: tools),
        connectBudget: const Duration(seconds: 5),
      );
      final initialize = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": {
            "loadSession": supportsLoad,
            "mcpCapabilities": {"http": http, "sse": true},
            "sessionCapabilities": {
              if (resumeCapability != null) "resume": resumeCapability else if (resume) "resume": <String, dynamic>{},
              if (close) "close": <String, dynamic>{},
            },
          },
        },
      });
      wrapper = await starting;
    }

    Future<PluginSession> create({required String sessionId, int count = 1}) async {
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final frame = await waitForFrame("session/new", count: count);
      fake.emit({
        "jsonrpc": "2.0",
        "id": frame["id"],
        "result": {"sessionId": sessionId},
      });
      return await creating;
    }

    Map<String, dynamic> expectedServer(int index) => {
      "type": "http",
      "name": "Sesori Device Canvas",
      "url": "http://127.0.0.1:700$index/mcp",
      "headers": [
        {"name": "Authorization", "value": "Bearer token-$index"},
      ],
    };

    test("start attaches tools and session/new provisions then binds a provisional capability", () async {
      await start(http: true);
      final creating = create(sessionId: "backend-new");
      final frame = await waitForFrame("session/new");

      expect(tools.provisionedBackendSessionIds, [null]);
      expect(frame["params"], {
        "cwd": "/repo",
        "mcpServers": [expectedServer(0)],
      });
      await creating;
      expect(tools.bindings, [(capabilityId: "cap-0", backendSessionId: "backend-new")]);
      expect(tools.revokedIds, isEmpty);
    });

    test("a failed session/new revokes its provisional capability", () async {
      await start(http: true);
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final frame = await waitForFrame("session/new");
      fake.emit({
        "jsonrpc": "2.0",
        "id": frame["id"],
        "error": {"code": -32000, "message": "creation failed"},
      });

      await expectLater(creating, throwsA(isA<AcpRpcException>()));
      expect(tools.bindings, isEmpty);
      expect(tools.revokedIds, ["cap-0"]);
    });

    test("a post-creation validation failure revokes the bound capability", () async {
      await start(http: true);
      plugin.validateTurnSelectionHandler = () async => throw StateError("selection rejected");
      final creating = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final frame = await waitForFrame("session/new");
      fake.emit({
        "jsonrpc": "2.0",
        "id": frame["id"],
        "result": {"sessionId": "backend-new"},
      });

      await expectLater(creating, throwsStateError);
      expect(tools.bindings, [(capabilityId: "cap-0", backendSessionId: "backend-new")]);
      expect(tools.revokedIds, ["cap-0"]);
    });

    test("agents without HTTP MCP keep the required empty server list", () async {
      await start(http: false);
      final creating = create(sessionId: "plain");
      final frame = await waitForFrame("session/new");
      expect(frame["params"], {"cwd": "/repo", "mcpServers": <Object?>[]});
      await creating;
      expect(tools.provisionedBackendSessionIds, isEmpty);
    });

    test("HTTP MCP without load or resume remains disabled", () async {
      await start(http: true, load: false);
      final creating = create(sessionId: "no-reactivation");
      final frame = await waitForFrame("session/new");
      expect(frame["params"], {"cwd": "/repo", "mcpServers": <Object?>[]});
      await creating;
      expect(tools.provisionedBackendSessionIds, isEmpty);
    });

    test("malformed resume capability cannot admit HTTP MCP", () async {
      await start(http: true, load: false, resumeCapability: "true");
      final creating = create(sessionId: "malformed-resume");
      final frame = await waitForFrame("session/new");
      expect(frame["params"], {"cwd": "/repo", "mcpServers": <Object?>[]});
      await creating;
      expect(tools.provisionedBackendSessionIds, isEmpty);
    });

    test("the shared ACP policy denies an unapproved agent that advertises HTTP MCP", () async {
      await plugin.dispose();
      await fake.close();
      fake = FakeAcpProcess();
      plugin = composeTestAcpPlugin(processFactory: (_) async => fake);

      await start(http: true);
      final creating = create(sessionId: "unapproved");
      final frame = await waitForFrame("session/new");
      expect(frame["params"], {"cwd": "/repo", "mcpServers": <Object?>[]});
      await creating;
      expect(tools.provisionedBackendSessionIds, isEmpty);
    });

    test("resident load provisions a bound capability and retains it only on success", () async {
      await start(http: true, load: true);
      plugin.primeSessionDirectory(sessionId: "stored", directory: "/repo");
      await plugin.sendPrompt(
        sessionId: "stored",
        promptId: "prompt-1",
        parts: [const PluginPromptPart.text(text: "hello")],
        variant: null,
        agent: null,
        model: null,
      );
      final load = await waitForFrame("session/load");
      expect(tools.provisionedBackendSessionIds, ["stored"]);
      expect(load["params"], {
        "sessionId": "stored",
        "cwd": "/repo",
        "mcpServers": [expectedServer(0)],
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": load["id"],
        "result": {"sessionId": "stored"},
      });
      final prompt = await waitForFrame("session/prompt");
      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "end_turn"},
      });

      expect(tools.bindings, isEmpty, reason: "resident capabilities are provisioned already bound");
      expect(tools.revokedIds, isEmpty);
      await plugin.deleteSession("stored");
      expect(tools.revokedIds, ["cap-0"]);
    });

    test("resident activation failure revokes only the newly provisioned capability", () async {
      await start(http: true, resume: true);
      plugin.primeSessionDirectory(sessionId: "stored", directory: "/repo");
      await plugin.sendPrompt(
        sessionId: "stored",
        promptId: "prompt-1",
        parts: [const PluginPromptPart.text(text: "hello")],
        variant: null,
        agent: null,
        model: null,
      );
      final resume = await waitForFrame("session/resume");
      expect(resume["params"], {
        "sessionId": "stored",
        "cwd": "/repo",
        "mcpServers": [expectedServer(0)],
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": resume["id"],
        "error": {"code": -32000, "message": "resume failed"},
      });
      final prompt = await waitForFrame("session/prompt");
      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "end_turn"},
      });

      expect(tools.revokedIds, ["cap-0"]);
    });

    test("failed deletion forces surviving sessions through MCP reactivation", () async {
      await start(http: true, load: true, close: true);
      await create(sessionId: "survivor");

      final deleting = plugin.deleteSession("survivor");
      final close = await waitForFrame("session/close");
      fake.emit({
        "jsonrpc": "2.0",
        "id": close["id"],
        "error": {"code": -32000, "message": "close failed"},
      });
      await expectLater(deleting, throwsA(isA<PluginOperationException>()));
      expect(tools.revokedIds, ["cap-0"]);

      final sending = plugin.sendPrompt(
        sessionId: "survivor",
        promptId: "prompt-after-failure",
        parts: [const PluginPromptPart.text(text: "continue")],
        variant: null,
        agent: null,
        model: null,
      );
      final load = await waitForFrame("session/load");
      expect(load["params"], {
        "sessionId": "survivor",
        "cwd": "/repo",
        "mcpServers": [expectedServer(1)],
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": load["id"],
        "result": {"sessionId": "survivor"},
      });
      final prompt = await waitForFrame("session/prompt");
      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await sending;
      expect(tools.provisionedBackendSessionIds, [null, "survivor"]);
    });

    test("deletion cancels and closes while an MCP revocation is draining", () async {
      await start(http: true, close: true);
      await create(sessionId: "deleting");
      tools.blockRevoke("cap-0");

      var deleted = false;
      final deleting = plugin.deleteSession("deleting").then((_) => deleted = true);
      final close = await waitForFrame("session/close");
      fake.emit({"jsonrpc": "2.0", "id": close["id"], "result": <String, Object?>{}});
      await Future<void>.delayed(Duration.zero);
      expect(deleted, isFalse);

      tools.releaseBlockedRevoke();
      await deleting;
      expect(deleted, isTrue);
    });

    test("replacement, archive, and reset revoke session capabilities", () async {
      await start(http: true);
      await create(sessionId: "same");

      final secondCreate = plugin.createSession(
        directory: "/repo",
        parentSessionId: null,
        parts: const [],
        userVisibleText: null,
        variant: null,
        agent: null,
        model: null,
      );
      final secondFrame = await waitForFrame("session/new", count: 2);
      expect(tools.revokedIds, isEmpty, reason: "the old capability stays valid during activation");
      fake.emit({
        "jsonrpc": "2.0",
        "id": secondFrame["id"],
        "result": {"sessionId": "same"},
      });
      await secondCreate;
      expect(tools.revokedIds, ["cap-0"]);

      await plugin.archiveSession(sessionId: "same");
      expect(tools.revokedIds, ["cap-0", "cap-1"]);

      await create(sessionId: "reset", count: 3);
      await plugin.resetConnectionAfterExit();
      expect(tools.revokedIds, ["cap-0", "cap-1", "cap-2"]);
    });

    test("failed same-id creation preserves the resident session capability", () async {
      await start(http: true);
      await create(sessionId: "same");
      plugin.validateTurnSelectionHandler = () async => throw StateError("selection rejected");

      await expectLater(create(sessionId: "same", count: 2), throwsStateError);
      expect(tools.revokedIds, ["cap-1"]);

      plugin.validateTurnSelectionHandler = null;
      final sending = plugin.sendPrompt(
        sessionId: "same",
        promptId: "prompt-after-replacement-failure",
        parts: [const PluginPromptPart.text(text: "continue")],
        variant: null,
        agent: null,
        model: null,
      );
      final prompt = await waitForFrame("session/prompt");
      expect(fake.written.where((frame) => frame["method"] == "session/load"), isEmpty);
      fake.emit({
        "jsonrpc": "2.0",
        "id": prompt["id"],
        "result": {"stopReason": "end_turn"},
      });
      await sending;

      await plugin.archiveSession(sessionId: "same");
      expect(tools.revokedIds, ["cap-1", "cap-0"]);
    });

    test("dispose revokes live capabilities and disposes the generation host", () async {
      await start(http: true);
      await create(sessionId: "live");

      await wrapper!.shutdown(budget: null);
      expect(tools.revokedIds, ["cap-0"]);
      expect(tools.disposed, isTrue);
    });

    test("reset starts every capability revocation before awaiting a blocked one", () async {
      await start(http: true);
      await create(sessionId: "first");
      await create(sessionId: "second", count: 2);
      tools.blockRevoke("cap-0");

      final resetting = plugin.resetConnectionAfterExit();
      for (var attempt = 0; attempt < 100 && tools.revokedIds.length < 2; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(tools.revokedIds, containsAll(["cap-0", "cap-1"]));

      tools.releaseBlockedRevoke();
      await resetting;
    });
  });
}

class _AgentToolHost() implements PluginAgentToolHost {
  final List<String?> provisionedBackendSessionIds = [];
  final List<({String capabilityId, String backendSessionId})> bindings = [];
  final List<String> revokedIds = [];
  bool disposed = false;
  String? _blockedRevokeId;
  Completer<void>? _revokeGate;

  void blockRevoke(String capabilityId) {
    _blockedRevokeId = capabilityId;
    _revokeGate = Completer<void>();
  }

  void releaseBlockedRevoke() {
    final gate = _revokeGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<PluginAgentToolMcpCapability> provisionMcp({required String? backendSessionId}) async {
    final index = provisionedBackendSessionIds.length;
    provisionedBackendSessionIds.add(backendSessionId);
    return PluginAgentToolMcpCapability(
      id: "cap-$index",
      url: "http://127.0.0.1:700$index/mcp",
      bearerToken: "token-$index",
    );
  }

  @override
  Future<void> bindMcp({
    required PluginAgentToolMcpCapability capability,
    required String backendSessionId,
  }) async {
    bindings.add((capabilityId: capability.id, backendSessionId: backendSessionId));
  }

  @override
  Future<void> revokeMcp({required PluginAgentToolMcpCapability capability}) async {
    revokedIds.add(capability.id);
    if (capability.id == _blockedRevokeId) await _revokeGate?.future;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<Map<String, dynamic>> invoke({
    required String backendSessionId,
    required PluginAgentTool tool,
    required Map<String, dynamic> arguments,
  }) => throw UnimplementedError();
}

class _Host({required final PluginAgentToolHost tools}) implements PluginHost, PluginAgentToolServicesProvider {
  @override
  final PluginAgentToolServices agentToolServices = _AgentToolServices(tools: tools);

  @override
  ServerClock get clock => const ServerClock();

  @override
  StartAbortSignal get startAborted => StartAbortSignal.never;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _AgentToolServices({@override required final PluginAgentToolHost tools})
    implements PluginAgentToolServices {
  @override
  PluginPrivateFileService get privateFiles => throw UnimplementedError();
}

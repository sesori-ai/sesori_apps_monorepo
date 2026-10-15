import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  test("typed MCP plugin replies require the native owning session and never reconnect", () async {
    final home = await Directory.systemTemp.createTemp("codex-mcp-form-plugin-");
    addTearDown(() => home.delete(recursive: true));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final socketReady = Completer<WebSocket>();
    final replied = Completer<Map<String, dynamic>>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socketReady.complete(socket);
      socket.listen((frame) {
        final message = jsonDecode(frame as String) as Map<String, dynamic>;
        if (message["result"] != null) {
          replied.complete(message);
        } else if (message["method"] == "initialize") {
          socket.add(
            jsonEncode({
              "id": message["id"],
              "result": {
                "userAgent": "fixture/0.160.1 (fixture)",
                "codexHome": home.path,
                "platformOs": "macos",
                "platformFamily": "unix",
              },
            }),
          );
        } else {
          fail("Unexpected native method ${message['method']}");
        }
      });
    });
    final plugin = createInjectedCodexPlugin(
      serverUrl: "ws://127.0.0.1:${server.port}",
      environment: {"CODEX_HOME": home.path},
      projectCwd: home.path,
      clientFactory: null,
      keepaliveInterval: const Duration(seconds: 30),
    );
    addTearDown(plugin.dispose);
    expect(await plugin.getPendingForms(sessionId: "thread"), isEmpty);
    expect(await plugin.getPendingExternalActions(sessionId: "thread"), isEmpty);
    expect(
      await plugin.replyToForm(requestId: "absent", sessionId: "thread", values: const {}),
      isA<PluginFormAlreadySettled>(),
    );
    expect(socketReady.isCompleted, isFalse);
    expect(
      await plugin.resolveMcpConnectorSetup(
        target: const PluginMcpConnectorOfferTarget(
          scope: PluginMcpSessionScope(sessionId: "thread"),
          offerKey: "fixture",
        ),
      ),
      isA<PluginMcpConnectorSetupUnavailable>().having(
        (r) => r.reason,
        "reason",
        PluginMcpConnectorSetupUnavailableReason.liveSessionRequired,
      ),
    );
    expect(socketReady.isCompleted, isFalse);
    await plugin.initialize();
    final asked = plugin.events.firstWhere((event) => event is BridgeSseQuestionAsked);
    (await socketReady.future).add(
      jsonEncode({
        "id": "native-form",
        "method": "mcpServer/elicitation/request",
        "params": {
          "threadId": "thread",
          "serverName": "fixture",
          "mode": "form",
          "message": "Fixture form",
          "requestedSchema": {
            "type": "object",
            "properties": {
              "count": {"type": "integer"},
            },
            "required": ["count"],
          },
        },
      }),
    );
    final notice = await asked.timeout(const Duration(seconds: 2)) as BridgeSseQuestionAsked;
    final form = (await plugin.getPendingForms(sessionId: "thread")).single;
    expect(form.id, notice.id);
    await expectLater(
      plugin.replyToQuestion(
        questionId: form.id,
        sessionId: "foreign",
        answers: const [
          ["Accept"],
        ],
      ),
      throwsA(isA<PluginOperationException>()),
    );
    expect(
      await plugin.replyToForm(requestId: form.id, sessionId: "foreign", values: const {}),
      isA<PluginFormAlreadySettled>(),
    );
    expect(replied.isCompleted, isFalse);
    expect(
      await plugin.replyToForm(
        requestId: form.id,
        sessionId: "thread",
        values: const {"field-0": PluginFormIntegerValue(value: 2)},
      ),
      isA<PluginFormAccepted>(),
    );
    expect(await replied.future.timeout(const Duration(seconds: 2)), {
      "jsonrpc": "2.0",
      "id": "native-form",
      "result": {
        "action": "accept",
        "content": {"count": 2},
      },
    });
  });

  test("MCP reads use the current connection and never reconnect or mutate native configuration", () async {
    final home = await Directory.systemTemp.createTemp("codex-mcp-plugin-");
    addTearDown(() => home.delete(recursive: true));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final socketReady = Completer<WebSocket>();
    final methods = <String>[];
    var connections = 0;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      connections++;
      socketReady.complete(socket);
      socket.listen((frame) {
        final request = jsonDecode(frame as String) as Map<String, dynamic>;
        methods.add(request["method"] as String);
        if (request["id"] == null) return;
        final result = switch (request["method"]) {
          "initialize" => {
            "userAgent": "codex-cli fixture",
            "codexHome": home.path,
            "platformOs": "macos",
            "platformFamily": "unix",
          },
          "mcpServerStatus/list" => {
            "data": [
              {"name": "fixture", "authStatus": "unsupported", "tools": <String, Object?>{}},
            ],
            "nextCursor": null,
          },
          "app/list" => {"data": <Object?>[]},
          _ => throw StateError("Unexpected native operation ${request['method']}"),
        };
        socket.add(jsonEncode({"id": request["id"], "result": result}));
      });
    });
    final plugin = createInjectedCodexPlugin(
      serverUrl: "ws://127.0.0.1:${server.port}",
      environment: {"CODEX_HOME": home.path},
      projectCwd: home.path,
      clientFactory: null,
      keepaliveInterval: const Duration(seconds: 30),
    );
    addTearDown(plugin.dispose);
    expect(plugin, isA<McpManagementPluginApi>());
    expect(await plugin.getMcpInventory(scope: const PluginMcpHarnessScope()), isA<PluginMcpInventoryUnavailable>());
    expect(
      await plugin.getMcpInventory(scope: const PluginMcpProjectScope(projectId: "project")),
      isA<PluginMcpInventoryUnavailable>().having(
        (value) => value.reason,
        "reason",
        PluginMcpInventoryUnavailableReason.unsupportedScope,
      ),
    );
    expect(socketReady.isCompleted, isFalse);
    await plugin.initialize();
    final inventory = await plugin.getMcpInventory(scope: const PluginMcpHarnessScope()) as PluginMcpInventorySnapshot;
    final entry = inventory.entries.single as PluginMcpServerSnapshot;
    expect(entry.target.serverKey, "fixture");
    expect(entry.actions, isEmpty);
    final readCount = methods.length;
    for (final action in PluginMcpServerAction.values) {
      expect(
        await plugin.executeMcpServerAction(target: entry.target, action: action),
        isA<PluginMcpActionUnavailable>(),
      );
    }
    expect(
      await plugin.getMcpInventory(scope: const PluginMcpProjectScope(projectId: "project")),
      isA<PluginMcpInventoryUnavailable>(),
    );
    expect(methods, hasLength(readCount));
    expect(methods, ["initialize", "mcpServerStatus/list", "app/list"]);
    final disconnected = plugin.workState.firstWhere((state) => state == PluginWorkState.unknown);
    await (await socketReady.future).close();
    await disconnected.timeout(const Duration(seconds: 2));
    expect(await plugin.getMcpInventory(scope: const PluginMcpHarnessScope()), isA<PluginMcpInventoryUnavailable>());
    expect(connections, 1);
  });

  test("native MCP authentication stays on the attached client and settles on disconnect", () async {
    final home = await Directory.systemTemp.createTemp("codex-mcp-auth-plugin-");
    addTearDown(() => home.delete(recursive: true));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final socketReady = Completer<WebSocket>();
    final methods = <String>[];
    var connections = 0;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      connections++;
      socketReady.complete(socket);
      socket.listen((frame) {
        final request = jsonDecode(frame as String) as Map<String, dynamic>;
        methods.add(request["method"] as String);
        final result = switch (request["method"]) {
          "initialize" => {
            "userAgent": "fixture/0.160.1 (fixture)",
            "codexHome": home.path,
            "platformOs": "macos",
            "platformFamily": "unix",
          },
          "mcpServerStatus/list" => {
            "data": [
              {"name": "fixture", "authStatus": "notLoggedIn", "tools": <String, Object?>{}},
            ],
          },
          "mcpServer/oauth/login" => {
            "authorizationUrl": Uri.https("issuer.fixture", "/authorize", {
              "state": "fixture",
              "redirect_uri": "http://127.0.0.1:43123/callback",
            }).toString(),
          },
          _ => throw StateError("Unexpected native operation ${request['method']}"),
        };
        socket.add(jsonEncode({"id": request["id"], "result": result}));
      });
    });
    final plugin = createInjectedCodexPlugin(
      serverUrl: "ws://127.0.0.1:${server.port}",
      environment: {"CODEX_HOME": home.path},
      projectCwd: home.path,
      clientFactory: null,
      keepaliveInterval: const Duration(seconds: 30),
    );
    addTearDown(plugin.dispose);
    const target = PluginMcpServerTarget(
      scope: PluginMcpSessionScope(sessionId: "thread"),
      serverKey: "fixture",
    );
    await expectLater(
      plugin.beginMcpAuthentication(target: target),
      throwsA(
        isA<PluginMcpAuthenticationUnavailableException>().having(
          (error) => error.reason,
          "reason",
          PluginMcpAuthenticationUnavailableReason.liveSessionRequired,
        ),
      ),
    );
    await expectLater(
      plugin.forgetMcpAuthentication(target: target),
      throwsA(
        isA<PluginMcpAuthenticationUnavailableException>().having(
          (error) => error.reason,
          "reason",
          PluginMcpAuthenticationUnavailableReason.notSupported,
        ),
      ),
    );
    expect(socketReady.isCompleted, isFalse);
    await plugin.initialize();
    final operation = await plugin.beginMcpAuthentication(target: target);
    expect(operation, isA<PluginMcpNativeSettlementAuthentication>());
    final iterator = StreamIterator(operation.events);
    addTearDown(iterator.cancel);
    await iterator.moveNext();
    expect(iterator.current, isA<PluginMcpAuthenticationChallenge>());
    expect(methods, ["initialize", "mcpServerStatus/list", "mcpServer/oauth/login"]);
    await (await socketReady.future).close();
    await iterator.moveNext().timeout(const Duration(seconds: 2));
    expect(iterator.current, isA<PluginMcpAuthenticationFailed>());
    await expectLater(
      plugin.beginMcpAuthentication(target: target),
      throwsA(isA<PluginMcpAuthenticationUnavailableException>()),
    );
    expect(connections, 1);
  });
}

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
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
    expect(methods, ["initialize", "mcpServerStatus/list"]);
    final disconnected = plugin.workState.firstWhere((state) => state == PluginWorkState.unknown);
    await (await socketReady.future).close();
    await disconnected.timeout(const Duration(seconds: 2));
    expect(await plugin.getMcpInventory(scope: const PluginMcpHarnessScope()), isA<PluginMcpInventoryUnavailable>());
    expect(connections, 1);
  });
}

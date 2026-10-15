import "dart:async";
import "dart:convert";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/active_session_tracker.dart";
import "package:opencode_plugin/src/models/open_code_mcp_decode_exception.dart";
import "package:opencode_plugin/src/open_code_raw_http_client.dart";
import "package:opencode_plugin/src/opencode_api.dart";
import "package:opencode_plugin/src/opencode_plugin_impl.dart";
import "package:opencode_plugin/src/opencode_repository.dart";
import "package:opencode_plugin/src/opencode_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _directory = "/fixture/worktree";
const _name = "fixture/server?name";
const _session = {
  "id": "session-fixture",
  "slug": "fixture",
  "projectID": "fixture",
  "directory": _directory,
  "time": {"created": 1, "updated": 1},
};

OpenCodeService _service({required Future<http.Response> Function(http.Request) handler}) {
  final client = MockClient((request) => request.url.path == "/config" ? Future.value(_configuration()) : handler(request));
  addTearDown(client.close);
  final repository = OpenCodeRepository(
    OpenCodeApi(
      client: OpenCodeRawHttpClient(serverURL: "http://localhost:4096", password: null, client: client),
    ),
  );
  final service = OpenCodeService(repository, ActiveSessionTracker(repository));
  addTearDown(service.dispose);
  return service;
}

http.Response _inventory({required String status}) => http.Response(
  jsonEncode({
    _name: {"status": status, "error": "Native fixture diagnostic"},
  }),
  200,
);

http.Response _configuration() => http.Response(jsonEncode({"mcp": {_name: {"type": "remote", "url": "https://fixture.invalid/mcp"}}}), 200);

void main() {
  for (final disconnect in [false, true]) {
    test("slow native ${disconnect ? 'disconnect' : 'connect'} waits for completion without HTTP cancellation", () {
      fakeAsync((clock) {
        final response = Completer<http.Response>();
        final client = MockClient((_) => response.future);
        addTearDown(client.close);
        final api = OpenCodeApi(
          client: OpenCodeRawHttpClient(serverURL: "http://localhost:4096", password: null, client: client),
        );
        var completed = false;
        final operation = disconnect
            ? api.disconnectMcpServer(directory: _directory, name: _name)
            : api.connectMcpServer(directory: _directory, name: _name);
        unawaited(operation.then((_) => completed = true));
        clock.elapse(const Duration(minutes: 4));
        expect(completed, isFalse);
        response.complete(http.Response("true", 200));
        clock.flushMicrotasks();
        expect(completed, isTrue);
      });
    });
  }

  for (final (native, phase) in [
    ("connected", PluginMcpConnectionPhase.connected),
    ("disabled", PluginMcpConnectionPhase.disabled),
    ("needs_auth", PluginMcpConnectionPhase.authenticationRequired),
    ("needs_client_registration", PluginMcpConnectionPhase.authenticationRequired),
    ("future-state", PluginMcpConnectionPhase.unknown),
    ("failed", null),
  ]) {
    test("native $native retains its status without inferring credentials or metadata", () async {
      const scope = PluginMcpProjectScope(projectId: _directory);
      final service = _service(handler: (_) async => _inventory(status: native));
      final result = await service.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot;
      final server = result.entries.single as PluginMcpServerSnapshot;
      expect(result.servers, isA<PluginMcpCatalogAvailable>());
      expect(result.connectors, isA<PluginMcpCatalogNotSupported>());
      expect(server.target.scope, same(scope));
      expect(server.target.serverKey, _name);
      expect(server.configuration, isNull);
      expect(server.endpointOrigin, isNull);
      expect(server.tools, isA<PluginMcpToolsUnavailable>());
      if (native == "needs_client_registration") {
        expect((server.authentication as PluginMcpAuthenticationCapabilityUnavailable).reason,
          PluginMcpAuthenticationCapabilityUnavailableReason.nativeConfigurationRequired);
      } else {
        expect((server.authentication as PluginMcpAuthenticationCapabilityAvailable).effectScope,
          PluginMcpActionEffectScope.harness);
      }
      expect((server.credentialForgetting as PluginMcpAuthenticationCapabilityAvailable).effectScope,
        PluginMcpActionEffectScope.harness);
      expect(
        server.authorization,
        native == "needs_auth" || native == "needs_client_registration"
            ? PluginMcpAuthorizationState.required
            : PluginMcpAuthorizationState.unknown,
      );
      if (phase == null) {
        expect(server.connection, isA<PluginMcpConnectionFailed>());
      } else {
        expect((server.connection as PluginMcpConnectionStatus).phase, phase);
      }
      expect(server.actions.map((capability) => capability.action), switch (native) {
        "disabled" => [PluginMcpServerAction.enable],
        "future-state" => isEmpty,
        _ => [PluginMcpServerAction.reconnect, PluginMcpServerAction.disable],
      });
      expect(
        server.actions.every((capability) => capability.effectScope == PluginMcpActionEffectScope.project),
        isTrue,
      );
      expect(server.actions.clear, throwsUnsupportedError);
    });
  }

  for (final scope in [
    const PluginMcpProjectScope(projectId: _directory),
    const PluginMcpSessionScope(sessionId: "session-fixture"),
  ]) {
    test("inventory resolves only the exact native directory for $scope", () async {
      final calls = <http.Request>[];
      final service = _service(
        handler: (request) async {
          calls.add(request);
          expect(request.method, "GET");
          if (request.url.path == "/session/session-fixture") {
            expect(request.headers["x-opencode-directory"], isNull);
            return http.Response(jsonEncode(_session), 200);
          }
          expect(request.url.path, "/mcp");
          expect(request.headers["x-opencode-directory"], _directory);
          return _inventory(status: "connected");
        },
      );
      final result = await service.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot;
      expect((result.entries.single as PluginMcpServerSnapshot).target.scope, same(scope));
      expect(calls.length, scope is PluginMcpSessionScope ? 2 : 1);
    });

    for (final action in PluginMcpServerAction.values) {
      test("$action uses only the named native directory control for $scope", () async {
        final posts = <http.Request>[];
        final service = _service(
          handler: (request) async {
            if (request.url.path == "/session/session-fixture") return http.Response(jsonEncode(_session), 200);
            expect(request.headers["x-opencode-directory"], _directory);
            if (request.method == "GET") return _inventory(status: "disabled");
            posts.add(request);
            expect(request.method, "POST");
            expect(request.url.pathSegments, [
              "mcp",
              _name,
              action == PluginMcpServerAction.disable ? "disconnect" : "connect",
            ]);
            expect(request.body, isEmpty);
            return http.Response("true", 200);
          },
        );
        final result = await service.executeMcpServerAction(
          target: PluginMcpServerTarget(scope: scope, serverKey: _name),
          action: action,
        ) as PluginMcpActionCompleted;
        expect(result.effectScope, PluginMcpActionEffectScope.project);
        expect(posts, hasLength(1));
      });
    }
  }

  test("harness inventory and control are unavailable without HTTP or an implicit directory", () async {
    final service = _service(handler: (_) async => throw StateError("Unexpected native work"));
    expect(
      (await service.getMcpInventory(scope: const PluginMcpHarnessScope()) as PluginMcpInventoryUnavailable).reason,
      PluginMcpInventoryUnavailableReason.unsupportedScope,
    );
    expect(
      (await service.executeMcpServerAction(
        target: const PluginMcpServerTarget(scope: PluginMcpHarnessScope(), serverKey: _name),
        action: PluginMcpServerAction.enable,
      ) as PluginMcpActionUnavailable).reason,
      PluginMcpActionUnavailableReason.unsupportedScope,
    );
  });

  test("same-name targets in separate and non-ASCII directories remain independent", () async {
    final directories = <String>[];
    final service = _service(
      handler: (request) async {
        directories.add(Uri.decodeFull(request.headers["x-opencode-directory"]!));
        if (request.method == "GET") return _inventory(status: "connected");
        return http.Response("true", 200);
      },
    );
    for (final directory in ["/fixture/first", "/fixture/é space"]) {
      final scope = PluginMcpProjectScope(projectId: directory);
      final inventory = await service.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot;
      final target = (inventory.entries.single as PluginMcpServerSnapshot).target;
      expect(target.scope, same(scope));
      expect(target.serverKey, _name);
      await service.executeMcpServerAction(target: target, action: PluginMcpServerAction.reconnect);
    }
    expect(directories, [
      for (final directory in ["/fixture/first", "/fixture/é space"]) ...List.filled(3, directory),
    ]);
  });

  test("inventory sorting is stable and an absent target issues no native write", () async {
    final service = _service(
      handler: (request) async {
        expect(request.method, "GET");
        return http.Response('{"z":{"status":"connected"},"a":{"status":"disabled"}}', 200);
      },
    );
    const scope = PluginMcpProjectScope(projectId: _directory);
    final inventory = await service.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot;
    expect(inventory.entries.whereType<PluginMcpServerSnapshot>().map((server) => server.name), ["a", "z"]);
    expect(inventory.entries.clear, throwsUnsupportedError);
    expect(
      (await service.executeMcpServerAction(
        target: const PluginMcpServerTarget(scope: scope, serverKey: _name),
        action: PluginMcpServerAction.reconnect,
      ) as PluginMcpActionUnavailable).reason,
      PluginMcpActionUnavailableReason.targetNotFound,
    );
  });

  test("empty native status map remains an available empty inventory", () async {
    final service = _service(handler: (_) async => http.Response("{}", 200));
    final inventory = await service.getMcpInventory(
      scope: const PluginMcpProjectScope(projectId: _directory),
    ) as PluginMcpInventorySnapshot;
    expect(inventory.servers, isA<PluginMcpCatalogAvailable>());
    expect(inventory.entries, isEmpty);
  });

  test("HTTP and decoder failures retain their causes and cannot become empty success", () async {
    for (final (body, status) in [
      ("[]", 200),
      ("not-json", 200),
      ('{"fixture":null}', 200),
      ("Native fixture failure", 500),
    ]) {
      final service = _service(handler: (_) async => http.Response(body, status));
      const scope = PluginMcpProjectScope(projectId: _directory);
      final result = await service.getMcpInventory(scope: scope) as PluginMcpInventoryReadFailed;
      if (status == 200) {
        expect(result.cause, isA<OpenCodeMcpDecodeException>());
        expect(
          (result.cause as OpenCodeMcpDecodeException).innerError,
          body == '{"fixture":null}' ? isA<TypeError>() : isA<FormatException>(),
        );
      } else {
        expect((result.cause as OpenCodeApiException).responseBody, body);
      }
      final action = await service.executeMcpServerAction(
        target: const PluginMcpServerTarget(scope: scope, serverKey: _name),
        action: PluginMcpServerAction.disable,
      ) as PluginMcpActionFailed;
      expect(action.cause.runtimeType, result.cause.runtimeType);
      expect(action.causeStackTrace.toString(), isNotEmpty);
    }
  });

  test("a malformed session lookup retains the decoding error before any MCP operation", () async {
    final service = _service(
      handler: (request) async {
        expect(request.url.path, "/session/session-fixture");
        return http.Response("{}", 200);
      },
    );
    const scope = PluginMcpSessionScope(sessionId: "session-fixture");
    final result = await service.getMcpInventory(scope: scope) as PluginMcpInventoryReadFailed;
    expect((result.cause as OpenCodeMcpDecodeException).innerError, isA<TypeError>());
  });

  test("concrete v1 plugin exposes management through its existing HTTP connection", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var connected = true;
    final calls = <String>[];
    final subscription = server.listen((request) async {
      calls.add(request.uri.path);
      expect(request.headers.value("x-opencode-directory"), _directory);
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == "/mcp") {
        request.response.write(_inventory(status: connected ? "connected" : "disabled").body);
      } else if (request.uri.path == "/config") {
        request.response.write(_configuration().body);
      } else {
        expect(request.uri.pathSegments, ["mcp", _name, "disconnect"]);
        connected = false;
        request.response.write("true");
      }
      await request.response.close();
    });
    final plugin = OpenCodePlugin(serverUrl: "http://127.0.0.1:${server.port}");
    addTearDown(() async {
      await plugin.dispose();
      await subscription.cancel();
      await server.close(force: true);
    });
    final McpManagementPluginApi management = plugin;
    const scope = PluginMcpProjectScope(projectId: _directory);
    final before = await management.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot;
    await management.executeMcpServerAction(
      target: (before.entries.single as PluginMcpServerSnapshot).target,
      action: PluginMcpServerAction.disable,
    );
    final after = await management.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot;
    expect(
      ((after.entries.single as PluginMcpServerSnapshot).connection as PluginMcpConnectionStatus).phase,
      PluginMcpConnectionPhase.disabled,
    );
    expect(calls, hasLength(7));
  });
}

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/open_code_raw_http_client.dart";
import "package:opencode_plugin/src/v2/api/opencode_v2_api.dart";
import "package:opencode_plugin/src/v2/mappers/v2_form_answer_mapper.dart";
import "package:opencode_plugin/src/v2/mappers/v2_form_answer_validator.dart";
import "package:opencode_plugin/src/v2/models/v2_decode_exception.dart";
import "package:opencode_plugin/src/v2/opencode_v2_plugin.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_activity_tracker.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_compaction_tracker.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_repository.dart";
import "package:opencode_plugin/src/v2/repositories/v2_message_mapper.dart";
import "package:opencode_plugin/src/v2/repositories/v2_model_mapper.dart";
import "package:opencode_plugin/src/v2/services/opencode_v2_service.dart";
import "package:opencode_plugin/src/v2/services/v2_mcp_authentication_service.dart";
import "package:opencode_plugin/src/v2/sse/v2_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/v2_fixtures.dart";

const _directory = "/fixture/worktree";
const _name = "fixture/server?name";

OpenCodeV2Service _service({required Future<http.Response> Function(http.Request) handler}) {
  final client = MockClient(handler);
  addTearDown(client.close);
  final repository = OpenCodeV2Repository(
    api: OpenCodeV2Api(
      client: OpenCodeRawHttpClient(serverURL: "http://localhost:4096", password: null, client: client),
    ),
    modelMapper: const V2ModelMapper(pluginId: "fixture"),
    messageMapper: const V2MessageMapper(),
  );
  return OpenCodeV2Service(
    repository: repository,
    mcpAuthentication: V2McpAuthenticationService(
      repository: repository,
      pollInterval: const Duration(milliseconds: 1),
    ),
    tracker: OpenCodeV2ActivityTracker(),
    compactions: OpenCodeV2CompactionTracker(),
    mapper: const V2EventMapper(
      modelMapper: V2ModelMapper(pluginId: "fixture"),
      messageMapper: V2MessageMapper(),
    ),
    modelMapper: const V2ModelMapper(pluginId: "fixture"),
    formAnswerMapper: const V2FormAnswerMapper(),
    formAnswerValidator: const V2FormAnswerValidator(),
  );
}

http.Response _inventory({required String status}) => http.Response(
  jsonEncode({
    "location": {"directory": _directory},
    "data": [
      {
        "name": _name,
        "status": {"status": status, "error": "Native fixture diagnostic"},
      },
    ],
  }),
  200,
);

void main() {
  for (final integrationId in <String?>[null, "native-integration"]) {
    test("authentication limitation follows the native integration ID: $integrationId", () async {
      final service = _service(
        handler: (_) async => http.Response(
          jsonEncode({
            "location": {"directory": _directory},
            "data": [
              {
                "name": _name,
                "status": {"status": "needs_auth", "error": "Fixture authentication required"},
                "integrationID": ?integrationId,
              },
            ],
          }),
          200,
        ),
      );
      final inventory = await service.getMcpInventory(
        scope: const PluginMcpProjectScope(projectId: _directory),
      ) as PluginMcpInventorySnapshot;
      final server = inventory.entries.single as PluginMcpServerSnapshot;
      if (integrationId == null) {
        expect(
          (server.authentication as PluginMcpAuthenticationCapabilityUnavailable).reason,
          PluginMcpAuthenticationCapabilityUnavailableReason.notSupported,
        );
      } else {
        expect(
          (server.authentication as PluginMcpAuthenticationCapabilityAvailable).effectScope,
          PluginMcpActionEffectScope.harness,
        );
      }
      expect(server.credentialForgetting, server.authentication);
    });
  }

  for (final disconnect in [false, true]) {
    test("a slow native ${disconnect ? 'disconnect' : 'connect'} remains pending until native completion", () {
      fakeAsync((clock) {
        final response = Completer<http.Response>();
        final client = MockClient((_) => response.future);
        addTearDown(client.close);
        final api = OpenCodeV2Api(
          client: OpenCodeRawHttpClient(serverURL: "http://localhost:4096", password: null, client: client),
        );
        var completed = false;
        final operation = disconnect
            ? api.disconnectMcpServer(directory: _directory, name: _name)
            : api.connectMcpServer(directory: _directory, name: _name);
        unawaited(operation.then((_) => completed = true));
        clock.elapse(const Duration(minutes: 4));
        expect(completed, isFalse);
        response.complete(http.Response("", 204));
        clock.flushMicrotasks();
        expect(completed, isTrue);
      });
    });
  }

  for (final (native, phase) in [
    ("connected", PluginMcpConnectionPhase.connected),
    ("pending", PluginMcpConnectionPhase.pending),
    ("disabled", PluginMcpConnectionPhase.disabled),
    ("needs_auth", PluginMcpConnectionPhase.authenticationRequired),
    ("future-state", PluginMcpConnectionPhase.unknown),
    ("failed", null),
  ]) {
    test("native $native stays distinct without inventing metadata or authentication", () async {
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
      expect(server.authentication, isA<PluginMcpAuthenticationCapabilityUnavailable>());
      expect(server.credentialForgetting, isA<PluginMcpAuthenticationCapabilityUnavailable>());
      expect(
        server.authorization,
        native == "needs_auth" ? PluginMcpAuthorizationState.required : PluginMcpAuthorizationState.unknown,
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
    test("inspection preserves its exact project/session location and target identity in $scope", () async {
      final calls = <http.Request>[];
      final service = _service(
        handler: (request) async {
          calls.add(request);
          expect(request.method, "GET");
          if (request.url.path == "/api/session/session-fixture") {
            return http.Response(
              jsonEncode({
                "data": {
                  ...v2SessionFixture,
                  "location": {"directory": _directory},
                },
              }),
              200,
            );
          }
          expect(request.url.path, "/api/mcp");
          expect(request.url.queryParameters, {"location[directory]": _directory});
          return _inventory(status: "connected");
        },
      );
      final result = await service.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot;
      expect((result.entries.single as PluginMcpServerSnapshot).target.scope, same(scope));
      expect(calls.length, scope is PluginMcpSessionScope ? 2 : 1);
    });

    for (final action in PluginMcpServerAction.values) {
      test("$action uses only the named native location control in $scope", () async {
        final posts = <http.Request>[];
        final service = _service(
          handler: (request) async {
            if (request.url.path == "/api/session/session-fixture") {
              return http.Response(
                jsonEncode({
                  "data": {
                    ...v2SessionFixture,
                    "location": {"directory": _directory},
                  },
                }),
                200,
              );
            }
            expect(request.url.queryParameters, {"location[directory]": _directory});
            if (request.method == "GET") return _inventory(status: "disabled");
            posts.add(request);
            expect(request.method, "POST");
            expect(request.url.pathSegments, [
              "api",
              "experimental",
              "mcp",
              _name,
              action == PluginMcpServerAction.disable ? "disconnect" : "connect",
            ]);
            expect(request.body, isEmpty);
            return http.Response("", 204);
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

  test("harness scope is unavailable without choosing a working directory or issuing HTTP", () async {
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

  test("same-name servers in different locations retain separate targets", () async {
    final directories = <String>[];
    final service = _service(
      handler: (request) async {
        directories.add(request.url.queryParameters["location[directory]"]!);
        return _inventory(status: "connected");
      },
    );
    for (final directory in ["/fixture/first", "/fixture/second"]) {
      final scope = PluginMcpProjectScope(projectId: directory);
      final inventory = await service.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot;
      final target = (inventory.entries.single as PluginMcpServerSnapshot).target;
      expect(target.scope, same(scope));
      expect(target.serverKey, _name);
    }
    expect(directories, ["/fixture/first", "/fixture/second"]);
  });

  test("empty inventory stays available and a removed target issues no native mutation", () async {
    final service = _service(
      handler: (request) async {
        expect(request.method, "GET");
        return http.Response('{"data":[]}', 200);
      },
    );
    const scope = PluginMcpProjectScope(projectId: _directory);
    expect((await service.getMcpInventory(scope: scope) as PluginMcpInventorySnapshot).entries, isEmpty);
    expect(
      (await service.executeMcpServerAction(
        target: const PluginMcpServerTarget(scope: scope, serverKey: _name),
        action: PluginMcpServerAction.reconnect,
      ) as PluginMcpActionUnavailable).reason,
      PluginMcpActionUnavailableReason.targetNotFound,
    );
  });

  test("decode and HTTP failures retain original causes without successful empty inventory", () async {
    for (final (body, status) in [('{"data":"invalid"}', 200), ("Native fixture failure", 500)]) {
      final service = _service(handler: (_) async => http.Response(body, status));
      final result = await service.getMcpInventory(
        scope: const PluginMcpProjectScope(projectId: _directory),
      ) as PluginMcpInventoryReadFailed;
      if (status == 200) {
        expect(result.cause, isA<V2DecodeException>());
        expect((result.cause as V2DecodeException).innerError, isA<TypeError>());
      } else {
        expect((result.cause as OpenCodeApiException).statusCode, 500);
        expect((result.cause as OpenCodeApiException).responseBody, body);
      }
    }
  });

  test("failed session lookup retains the original native diagnostic before MCP access", () async {
    final service = _service(
      handler: (request) async {
        expect(request.url.path, "/api/session/session-fixture");
        return http.Response("Native session lookup failure", 500);
      },
    );
    const scope = PluginMcpSessionScope(sessionId: "session-fixture");
    final result = await service.getMcpInventory(scope: scope) as PluginMcpInventoryReadFailed;
    expect((result.cause as OpenCodeApiException).responseBody, "Native session lookup failure");
  });

  test("concrete plugin exposes shared MCP controls over its existing HTTP connection", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var connected = true;
    final requests = <String>[];
    final subscription = server.listen((request) async {
      requests.add(request.uri.path);
      expect(request.uri.queryParameters["location[directory]"], _directory);
      if (request.uri.path == "/api/mcp") {
        request.response.headers.contentType = ContentType.json;
        request.response.write(_inventory(status: connected ? "connected" : "disabled").body);
      } else {
        expect(request.uri.pathSegments, ["api", "experimental", "mcp", _name, "disconnect"]);
        connected = false;
        request.response.statusCode = 204;
      }
      await request.response.close();
    });
    final plugin = OpenCodeV2Plugin(
      serverUrl: "http://127.0.0.1:${server.port}",
      password: null,
      onConnected: () {},
      onDisconnected: () {},
    );
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
    expect(requests, hasLength(4));
  });
}

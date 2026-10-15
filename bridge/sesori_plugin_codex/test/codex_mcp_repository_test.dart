import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_mcp_status_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_mcp_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_mcp_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _server = <String, Object?>{
  "name": "fixture",
  "authStatus": "unsupported",
  "tools": <String, Object?>{},
  "resources": <Object?>[],
  "resourceTemplates": <Object?>[],
};

class _Transport({required List<Object?> responses}) implements CodexAppServerTransport {
  final List<Object?> _responses = List.of(responses);
  final calls = <({String method, Object? params})>[];
  @override
  Stream<CodexServerNotification> get notifications => const Stream.empty();
  @override
  Future<Object?> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    calls.add((method: method, params: params));
    final response = _responses.removeAt(0);
    if (response is Exception) throw response;
    if (response is Error) throw response;
    return response;
  }
}

CodexMcpRepository _repository({required _Transport transport}) => CodexMcpRepository(
  appServerApi: CodexAppServerApi(client: transport),
  mapper: const CodexMcpMapper(),
);

PluginMcpServerSnapshot _mapped({required Map<String, Object?> server}) =>
    const CodexMcpMapper()
            .map(
              servers: [CodexMcpServerStatusDto.fromJson(server)],
              scope: const PluginMcpHarnessScope(),
            )
            .entries
            .single
        as PluginMcpServerSnapshot;

void main() {
  test("reads every native page using the exact thread without starting agent work", () async {
    final transport = _Transport(
      responses: [
        {
          "data": [
            {..._server, "name": "zulu"},
          ],
          "nextCursor": "opaque-cursor",
        },
        {
          "data": [_server],
          "nextCursor": null,
        },
      ],
    );
    const scope = PluginMcpSessionScope(sessionId: "native-thread");
    final result = await _repository(transport: transport).read(scope: scope) as PluginMcpInventorySnapshot;
    final entries = result.entries.cast<PluginMcpServerSnapshot>();
    expect(entries.map((entry) => entry.target.serverKey), ["fixture", "zulu"]);
    expect(entries.every((entry) => identical(entry.target.scope, scope)), isTrue);
    expect(transport.calls.map((call) => call.method), ["mcpServerStatus/list", "mcpServerStatus/list"]);
    expect(transport.calls.map((call) => call.params), [
      {"threadId": "native-thread", "limit": 100, "detail": "toolsAndAuthOnly"},
      {"threadId": "native-thread", "cursor": "opaque-cursor", "limit": 100, "detail": "toolsAndAuthOnly"},
    ]);
    expect(result.servers, isA<PluginMcpCatalogAvailable>());
    expect(result.connectors, isA<PluginMcpCatalogUnavailable>());
    expect(result.entries.clear, throwsUnsupportedError);
  });

  test("harness reads omit thread context and project scope makes no native request", () async {
    final transport = _Transport(
      responses: [
        {"data": <Object?>[], "nextCursor": null},
      ],
    );
    final repository = _repository(transport: transport);
    expect(
      await repository.read(scope: const PluginMcpProjectScope(projectId: "project")),
      isA<PluginMcpInventoryUnavailable>().having(
        (value) => value.reason,
        "reason",
        PluginMcpInventoryUnavailableReason.unsupportedScope,
      ),
    );
    expect(transport.calls, isEmpty);
    expect(await repository.read(scope: const PluginMcpHarnessScope()), isA<PluginMcpInventorySnapshot>());
    expect(transport.calls.single.params, {"limit": 100, "detail": "toolsAndAuthOnly"});
  });

  test("minimum-pin omission does not turn empty tools into a successful catalog", () {
    final entry = _mapped(server: _server);
    expect(
      entry.connection,
      isA<PluginMcpConnectionStatus>().having((value) => value.phase, "phase", PluginMcpConnectionPhase.unknown),
    );
    expect(entry.tools, isA<PluginMcpToolsUnavailable>());
    expect(entry.configuration, isNull);
    expect(entry.endpointOrigin, isNull);
    expect(entry.actions, isEmpty);
    expect(
      entry.authentication,
      isA<PluginMcpAuthenticationCapabilityUnavailable>().having(
        (value) => value.reason,
        "reason",
        PluginMcpAuthenticationCapabilityUnavailableReason.notSupported,
      ),
    );
  });

  test("target metadata retains opaque keys and strips endpoint secrets", () {
    final entry = _mapped(
      server: {
        ..._server,
        "authStatus": "oAuth",
        "runtimeStatus": "connected",
        "httpOrigin": "https://private-user:private-secret@fixture.example:9443/private?token=private#private",
        "serverInfo": {
          "title": " Display name ",
          "description": " Description ",
          "websiteUrl": "https://private.example",
        },
        "tools": {
          "different-map-key": {
            "name": "native-tool-name",
            "description": " Tool description ",
            "inputSchema": {"private": "ignored"},
          },
        },
      },
    );
    expect(entry.target.serverKey, "fixture");
    expect(entry.name, "Display name");
    expect(entry.description, "Description");
    expect(entry.endpointOrigin, "https://fixture.example:9443");
    expect(entry.configuration, isNull);
    expect(entry.authorization, PluginMcpAuthorizationState.authenticated);
    final tools = (entry.tools as PluginMcpToolsAvailable).tools;
    expect(tools.single.name, "native-tool-name");
    expect(tools.single.description, "Tool description");
    expect(tools.clear, throwsUnsupportedError);
    expect(
      entry.authentication,
      isA<PluginMcpAuthenticationCapabilityUnavailable>().having(
        (value) => value.reason,
        "reason",
        PluginMcpAuthenticationCapabilityUnavailableReason.notImplemented,
      ),
    );
    expect(
      entry.credentialForgetting,
      isA<PluginMcpAuthenticationCapabilityUnavailable>().having(
        (value) => value.reason,
        "reason",
        PluginMcpAuthenticationCapabilityUnavailableReason.notSupported,
      ),
    );
  });

  test("unknown native variants retain unknown state", () {
    final dto = CodexMcpServerStatusDto.fromJson({
      ..._server,
      "authStatus": "future-auth",
      "runtimeStatus": "future-status",
    });
    expect(dto.authStatus, CodexMcpAuthStatus.unknown);
    expect(dto.runtimeStatus, CodexMcpRuntimeStatus.unknown);
    final entry = _mapped(server: {..._server, "authStatus": "future-auth", "runtimeStatus": "future-status"});
    expect(entry.authorization, PluginMcpAuthorizationState.unknown);
    expect(entry.tools, isA<PluginMcpToolsUnavailable>());
  });

  test("connected empty tools are available, but discovery failure remains explicit", () {
    expect(
      _mapped(server: {..._server, "runtimeStatus": "connected"}).tools,
      isA<PluginMcpToolsAvailable>().having((value) => value.tools, "tools", isEmpty),
    );
    final entry = _mapped(
      server: {
        ..._server,
        "runtimeStatus": "authenticationRequired",
        "authStatus": "notLoggedIn",
        "toolsError": "private native diagnostics",
      },
    );
    expect(entry.authorization, PluginMcpAuthorizationState.required);
    expect(
      entry.tools,
      isA<PluginMcpToolsFailed>().having((value) => value.message, "message", isNot(contains("private"))),
    );
  });

  for (final (native, phase) in [
    ("notStarted", PluginMcpConnectionPhase.pending),
    ("starting", PluginMcpConnectionPhase.connecting),
    ("connected", PluginMcpConnectionPhase.connected),
    ("authenticationRequired", PluginMcpConnectionPhase.authenticationRequired),
    ("disabled", PluginMcpConnectionPhase.disabled),
  ]) {
    test("maps native $native without guessing from tools", () {
      expect(
        _mapped(server: {..._server, "runtimeStatus": native}).connection,
        isA<PluginMcpConnectionStatus>().having((value) => value.phase, "phase", phase),
      );
    });
  }
  for (final native in ["failed", "cancelled"]) {
    test("maps native $native to an explicit safe failure", () {
      expect(_mapped(server: {..._server, "runtimeStatus": native}).connection, isA<PluginMcpConnectionFailed>());
    });
  }

  for (final auth in ["bearerToken", "oAuth"]) {
    test("native $auth is authenticated independently of runtime state", () {
      expect(
        _mapped(server: {..._server, "authStatus": auth}).authorization,
        PluginMcpAuthorizationState.authenticated,
      );
    });
  }

  for (final value in [
    null,
    <Object?>[],
    {"data": "invalid"},
    {
      "data": [
        {..._server, "tools": <Object?>[]},
      ],
    },
  ]) {
    test("malformed native page ${value.runtimeType} stays a failed read", () async {
      final transport = _Transport(responses: [value]);
      final result = await _repository(
        transport: transport,
      ).read(scope: const PluginMcpHarnessScope()) as PluginMcpInventoryReadFailed;
      expect(result.cause, isA<CodexMcpInventoryReadException>());
      expect(result.causeStackTrace.toString(), isNotEmpty);
    });
  }

  test("a later-page native failure retains its original cause instead of partial success", () async {
    final cause = CodexRpcException(method: "mcpServerStatus/list", code: -32000, message: "fixture native failure");
    final transport = _Transport(
      responses: [
        {
          "data": [_server],
          "nextCursor": "next",
        },
        cause,
      ],
    );
    final result = await _repository(
      transport: transport,
    ).read(scope: const PluginMcpSessionScope(sessionId: "original")) as PluginMcpInventoryReadFailed;
    expect(result.cause, same(cause));
    expect(transport.calls, hasLength(2));
    expect(transport.calls.every((call) => (call.params! as Map)["threadId"] == "original"), isTrue);
  });

  test("DTO diagnostics omit metadata and their native tool collection is immutable", () {
    final dto = CodexMcpServerStatusDto.fromJson({
      ..._server,
      "httpOrigin": "https://private.example/path",
      "toolsError": "private diagnostic",
    });
    expect(dto.toString(), isNot(contains("private")));
    expect(dto.tools.clear, throwsUnsupportedError);
  });
}

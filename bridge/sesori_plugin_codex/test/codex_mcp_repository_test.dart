import "dart:io";

import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_mcp_status_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_mcp_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_mcp_mapper.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
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
  mapper: CodexMcpMapper(userAgent: "fixture/0.160.1 (fixture)"),
);

PluginMcpServerSnapshot _mapped({required Map<String, Object?> server}) =>
    CodexMcpMapper(userAgent: "fixture/0.160.1 (fixture)")
            .map(
              servers: [CodexMcpServerStatusDto.fromJson(server)],
              scope: const PluginMcpHarnessScope(),
            )
            .entries
            .single
        as PluginMcpServerSnapshot;

void main() {
  test("server transport and decoder failures leave healthy connector offers visible", () async {
    for (final scope in [const PluginMcpHarnessScope(), const PluginMcpSessionScope(sessionId: "original")]) {
      for (final failure in [
        StateError("fixture server failure"),
        {
          "data": [
            {"invalid": true},
          ],
        },
      ]) {
        final transport = _Transport(
          responses: [
            failure,
            {
              "data": [
                {"id": "offer", "name": "Fixture offer"},
              ],
            },
          ],
        );
        final stderr = BufferingStdout();
        final previous = Log.level;
        try {
          Log.level = LogLevel.warning;
          await IOOverrides.runZoned(() async {
            final result = await _repository(
              transport: transport,
            ).read(scope: scope) as PluginMcpInventorySnapshot;
            expect(result.servers, isA<PluginMcpCatalogUnavailable>());
            expect(result.connectors, isA<PluginMcpCatalogAvailable>());
            expect(result.entries.single, isA<PluginMcpConnectorOfferSnapshot>());
            expect(transport.calls.map((call) => call.method), ["mcpServerStatus/list", "app/list"]);
          }, stderr: () => stderr);
          expect(stderr.text, contains("MCP server inventory unavailable"));
          expect(stderr.text, contains(scope is PluginMcpSessionScope ? "thread original" : "harness"));
        } finally {
          Log.level = previous;
        }
      }
    }
  });
  for (final scope in [const PluginMcpHarnessScope(), const PluginMcpSessionScope(sessionId: "thread")]) {
    test("connector catalog keeps all pages and typed server/offer identities in $scope", () async {
      final transport = _Transport(
        responses: [
          {
            "data": [_server],
          },
          {
            "data": [
              {"id": "zulu", "name": "Zulu", "isAccessible": true},
            ],
            "nextCursor": "catalog-cursor",
          },
          {
            "data": [
              {
                "id": "fixture",
                "name": "Fixture connector",
                "description": " Description ",
                "installUrl": "https://fixture.example/private?secret=value",
              },
              {"id": "disabled", "name": "Disabled", "isEnabled": false, "isAccessible": true},
            ],
          },
        ],
      );
      final result = await _repository(transport: transport).read(scope: scope) as PluginMcpInventorySnapshot;
      expect(result.servers, isA<PluginMcpCatalogAvailable>());
      expect(result.connectors, isA<PluginMcpCatalogAvailable>());
      expect(result.entries.whereType<PluginMcpServerSnapshot>().single.target.serverKey, "fixture");
      final offers = result.entries.whereType<PluginMcpConnectorOfferSnapshot>().toList();
      expect(offers.map((offer) => offer.target.offerKey), ["disabled", "fixture", "zulu"]);
      expect(offers.map((offer) => offer.availability), [
        PluginMcpConnectorOfferAvailability.unavailable,
        PluginMcpConnectorOfferAvailability.setupRequired,
        PluginMcpConnectorOfferAvailability.available,
      ]);
      expect(offers[1].description, "Description");
      expect(offers[1].actions, [PluginMcpConnectorAction.setup]);
      expect(offers.first.actions, isEmpty);
      expect(offers.last.actions, isEmpty);
      expect(offers[1].actions.clear, throwsUnsupportedError);
      expect(offers.every((offer) => identical(offer.target.scope, scope)), isTrue);
      expect(result.entries.clear, throwsUnsupportedError);
      final threadId = scope is PluginMcpSessionScope ? scope.sessionId : null;
      expect(transport.calls.map((call) => call.method), ["mcpServerStatus/list", "app/list", "app/list"]);
      expect(transport.calls.skip(1).map((call) => call.params), [
        {"threadId": ?threadId, "limit": 100, "forceRefetch": true},
        {"threadId": ?threadId, "cursor": "catalog-cursor", "limit": 100, "forceRefetch": true},
      ]);
    });
  }

  for (final scope in [const PluginMcpHarnessScope(), const PluginMcpSessionScope(sessionId: "thread")]) {
    test("setup resolves the exact native offer across fresh pages in $scope", () async {
      final transport = _Transport(
        responses: [
          {
            "data": [
              {"id": "other", "name": "Other"},
            ],
            "nextCursor": "next",
          },
          {
            "data": [
              {"id": "fixture", "name": "Fixture", "installUrl": "https://fixture.example/setup?private=secret"},
            ],
          },
        ],
      );
      final result = await _repository(transport: transport).resolveSetup(
        target: PluginMcpConnectorOfferTarget(scope: scope, offerKey: "fixture"),
      ) as PluginMcpConnectorExternalSetup;
      expect(result.destination.toString(), "https://fixture.example/setup?private=secret");
      expect(transport.calls.map((call) => call.method), ["app/list", "app/list"]);
      expect(transport.calls.last.params, {
        "threadId": ?(scope is PluginMcpSessionScope ? scope.sessionId : null),
        "cursor": "next",
        "limit": 100,
        "forceRefetch": true,
      });
    });
  }

  test("setup rechecks entitlement and never invents a destination", () async {
    for (final (app, reason) in [
      (<String, Object?>{"id": "other", "name": "Other"}, PluginMcpConnectorSetupUnavailableReason.targetNotFound),
      ({"id": "fixture", "name": "Fixture"}, PluginMcpConnectorSetupUnavailableReason.nativeConfigurationRequired),
      (
        {"id": "fixture", "name": "Fixture", "isEnabled": false, "installUrl": "https://fixture.example"},
        PluginMcpConnectorSetupUnavailableReason.notSupported,
      ),
      (
        {"id": "fixture", "name": "Fixture", "isAccessible": true, "installUrl": "https://fixture.example"},
        PluginMcpConnectorSetupUnavailableReason.notSupported,
      ),
      for (final url in [
        "/setup",
        "http://fixture.example",
        "file:///setup",
        "data:text/plain,setup",
        "javascript:void(0)",
        "custom://setup",
        "https://user:secret@fixture.example",
      ])
        (
          {"id": "fixture", "name": "Fixture", "installUrl": url},
          PluginMcpConnectorSetupUnavailableReason.nativeConfigurationRequired,
        ),
    ]) {
      final transport = _Transport(
        responses: [
          {
            "data": [app],
          },
        ],
      );
      final result = await _repository(transport: transport).resolveSetup(
        target: const PluginMcpConnectorOfferTarget(scope: PluginMcpHarnessScope(), offerKey: "fixture"),
      ) as PluginMcpConnectorSetupUnavailable;
      expect(result.reason, reason);
      final inventoryTransport = _Transport(
        responses: [
          {
            "data": [_server],
          },
          {
            "data": [app],
          },
        ],
      );
      final inventory = await _repository(
        transport: inventoryTransport,
      ).read(scope: const PluginMcpHarnessScope()) as PluginMcpInventorySnapshot;
      expect(inventory.entries.whereType<PluginMcpConnectorOfferSnapshot>().single.actions, isEmpty);
    }
  });

  test("setup keeps catalog failures typed and project scopes issue no RPC", () async {
    final failure = StateError("fixture catalog failure");
    final transport = _Transport(responses: [failure]);
    final repository = _repository(transport: transport);
    final result = await repository.resolveSetup(
      target: const PluginMcpConnectorOfferTarget(scope: PluginMcpHarnessScope(), offerKey: "fixture"),
    ) as PluginMcpConnectorSetupFailed;
    expect((result.cause as CodexMcpInventoryReadException).innerError, same(failure));
    final unsupported = await repository.resolveSetup(
      target: const PluginMcpConnectorOfferTarget(
        scope: PluginMcpProjectScope(projectId: "project"),
        offerKey: "fixture",
      ),
    ) as PluginMcpConnectorSetupUnavailable;
    expect(unsupported.reason, PluginMcpConnectorSetupUnavailableReason.unsupportedScope);
    expect(transport.calls, hasLength(1));
  });

  test("connector names are trimmed and sorted without depending on opaque IDs", () async {
    final transport = _Transport(
      responses: [
        {"data": <Object>[]},
        {
          "data": [
            {"id": "asdk_b", "name": " BETA "},
            {"id": "z-fallback", "name": "  "},
            {"id": "asdk_z", "name": " Alpha "},
            {"id": "asdk_a", "name": "beta"},
          ],
        },
      ],
    );
    final result = await _repository(
      transport: transport,
    ).read(scope: const PluginMcpHarnessScope()) as PluginMcpInventorySnapshot;
    final offers = result.entries.whereType<PluginMcpConnectorOfferSnapshot>().toList();
    expect(offers.map((offer) => offer.target.offerKey), ["asdk_z", "asdk_a", "asdk_b", "z-fallback"]);
    expect(offers.map((offer) => offer.name), ["Alpha", "beta", "BETA", "z-fallback"]);
  });

  for (final failure in [
    StateError("fixture catalog transport failure"),
    {
      "data": [
        {"name": "Missing id"},
      ],
    },
    {"data": "malformed"},
  ]) {
    test("later-page catalog failure preserves configured servers: ${failure.runtimeType}", () async {
      final transport = _Transport(
        responses: [
          {
            "data": [_server],
          },
          {
            "data": [
              {"id": "partial", "name": "Discard partial page"},
            ],
            "nextCursor": "cursor",
          },
          failure,
        ],
      );
      final stderr = BufferingStdout();
      final previous = Log.level;
      try {
        Log.level = LogLevel.warning;
        await IOOverrides.runZoned(() async {
          final result = await _repository(
            transport: transport,
          ).read(scope: const PluginMcpSessionScope(sessionId: "thread")) as PluginMcpInventorySnapshot;
          expect(result.entries.single, isA<PluginMcpServerSnapshot>());
          expect(result.servers, isA<PluginMcpCatalogAvailable>());
          expect(result.connectors, isA<PluginMcpCatalogUnavailable>());
        }, stderr: () => stderr);
      } finally {
        Log.level = previous;
      }
      expect(stderr.text, contains("Connector catalog unavailable in thread thread"));
      if (failure is StateError) expect(stderr.text, contains("fixture catalog transport failure"));
    });
  }

  test("empty connector catalog is available and unsupported scope issues no native work", () async {
    final transport = _Transport(
      responses: [
        {
          "data": [_server],
        },
        {"data": <Object?>[]},
      ],
    );
    final repository = _repository(transport: transport);
    final result = await repository.read(scope: const PluginMcpHarnessScope()) as PluginMcpInventorySnapshot;
    expect(result.connectors, isA<PluginMcpCatalogAvailable>());
    expect(result.entries.whereType<PluginMcpConnectorOfferSnapshot>(), isEmpty);
    expect(
      await repository.read(scope: const PluginMcpProjectScope(projectId: "project")),
      isA<PluginMcpInventoryUnavailable>(),
    );
    expect(transport.calls, hasLength(2));
  });

  for (final (userAgent, supported) in [
    ("fixture/0.139.0 (fixture)", false),
    ("unknown", false),
    ("fixture/invalid (fixture)", false),
    ("fixture/0.160.1-alpha.1 (fixture)", false),
    ("fixture/0.160.1 (fixture)", true),
    ("fixture/0.161.0 (fixture)", true),
  ]) {
    test("session authentication uses verified native context support: $userAgent", () {
      final mapper = CodexMcpMapper(userAgent: userAgent);
      for (final scope in [const PluginMcpHarnessScope(), const PluginMcpSessionScope(sessionId: "thread")]) {
        for (final authStatus in ["notLoggedIn", "unsupported", "future-auth"]) {
          final entry =
              mapper
                      .map(
                        servers: [
                          CodexMcpServerStatusDto.fromJson({..._server, "authStatus": authStatus}),
                        ],
                        scope: scope,
                      )
                      .entries
                      .single
                  as PluginMcpServerSnapshot;
          if (authStatus != "notLoggedIn" || scope is PluginMcpSessionScope && !supported) {
            expect(
              entry.authentication,
              isA<PluginMcpAuthenticationCapabilityUnavailable>().having(
                (value) => value.reason,
                "reason",
                authStatus == "unsupported"
                    ? PluginMcpAuthenticationCapabilityUnavailableReason.notSupported
                    : authStatus == "future-auth"
                    ? PluginMcpAuthenticationCapabilityUnavailableReason.notImplemented
                    : PluginMcpAuthenticationCapabilityUnavailableReason.nativeConfigurationRequired,
              ),
            );
          } else {
            expect(entry.authentication, isA<PluginMcpAuthenticationCapabilityAvailable>());
          }
        }
      }
    });
  }

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
    final result = await _repository(transport: transport).readServers(scope: scope) as PluginMcpInventorySnapshot;
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
      await repository.readServers(scope: const PluginMcpProjectScope(projectId: "project")),
      isA<PluginMcpInventoryUnavailable>().having(
        (value) => value.reason,
        "reason",
        PluginMcpInventoryUnavailableReason.unsupportedScope,
      ),
    );
    expect(transport.calls, isEmpty);
    expect(await repository.readServers(scope: const PluginMcpHarnessScope()), isA<PluginMcpInventorySnapshot>());
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
      isA<PluginMcpAuthenticationCapabilityAvailable>().having(
        (value) => value.effectScope,
        "effect scope",
        PluginMcpActionEffectScope.harness,
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
      ).readServers(scope: const PluginMcpHarnessScope()) as PluginMcpInventoryReadFailed;
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
    ).readServers(scope: const PluginMcpSessionScope(sessionId: "original")) as PluginMcpInventoryReadFailed;
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

  test("native optional cursor omission ends pagination without rejecting a valid page", () async {
    final transport = _Transport(
      responses: [
        {
          "data": [_server],
        },
      ],
    );
    expect(
      await _repository(transport: transport).readServers(scope: const PluginMcpHarnessScope()),
      isA<PluginMcpInventorySnapshot>(),
    );
    expect(transport.calls, hasLength(1));
  });

  test("missing or null authorization metadata stays unknown", () {
    for (final server in [
      Map<String, Object?>.of(_server)..remove("authStatus"),
      {..._server, "authStatus": null},
    ]) {
      expect(_mapped(server: server).authorization, PluginMcpAuthorizationState.unknown);
    }
  });

  test("native map order cannot reorder displayed tools", () {
    final tools = <String, Object?>{
      "zulu": {"name": "Zulu tool"},
      "alpha": {"name": "Alpha tool"},
    };
    final first = _mapped(server: {..._server, "tools": tools}).tools as PluginMcpToolsAvailable;
    final second =
        _mapped(server: {..._server, "tools": Map.fromEntries(tools.entries.toList().reversed)}).tools
            as PluginMcpToolsAvailable;
    expect(first.tools.map((tool) => tool.name), ["Alpha tool", "Zulu tool"]);
    expect(second.tools.map((tool) => tool.name), first.tools.map((tool) => tool.name));
  });

  test("discovery failure logs original local diagnostics and exact context while returning safe text", () async {
    final transport = _Transport(
      responses: [
        {
          "data": [
            {..._server, "toolsError": "fixture native diagnostic"},
          ],
        },
      ],
    );
    final stderr = BufferingStdout();
    final previous = Log.level;
    try {
      Log.level = LogLevel.warning;
      await IOOverrides.runZoned(() async {
        final result = await _repository(
          transport: transport,
        ).readServers(scope: const PluginMcpSessionScope(sessionId: "original")) as PluginMcpInventorySnapshot;
        expect(
          ((result.entries.single as PluginMcpServerSnapshot).tools as PluginMcpToolsFailed).message,
          isNot(contains("fixture native diagnostic")),
        );
      }, stderr: () => stderr);
    } finally {
      Log.level = previous;
    }
    expect(stderr.text, contains("fixture native diagnostic"));
    expect(stderr.text, contains("fixture in thread original"));
  });

  test("cold thread returns live-session-required with no resume or scope fallback", () async {
    final cause = CodexRpcException(
      method: "mcpServerStatus/list",
      code: -32600,
      message: "thread not found: original",
    );
    final api = CodexAppServerApi(client: _Transport(responses: [cause]));
    await expectLater(
      api.listMcpServersPage(threadId: "original", cursor: null),
      throwsA(isA<CodexMcpThreadNotLoadedException>().having((error) => error.innerError, "cause", same(cause))),
    );
    final transport = _Transport(responses: [cause]);
    expect(
      await _repository(transport: transport).readServers(scope: const PluginMcpSessionScope(sessionId: "original")),
      isA<PluginMcpInventoryUnavailable>().having(
        (value) => value.reason,
        "reason",
        PluginMcpInventoryUnavailableReason.liveSessionRequired,
      ),
    );
    expect(transport.calls.map((call) => call.method), ["mcpServerStatus/list"]);
    expect((transport.calls.single.params! as Map)["threadId"], "original");
  });

  for (final (scope, code, message) in [
    (const PluginMcpHarnessScope(), -32600, "thread not found: original"),
    (const PluginMcpSessionScope(sessionId: "original"), -32600, "thread not found: another"),
    (const PluginMcpSessionScope(sessionId: "original"), -32000, "thread not found: original"),
  ]) {
    test("unrelated native error $code $message stays a typed failure for ${scope.runtimeType}", () async {
      final cause = CodexRpcException(method: "mcpServerStatus/list", code: code, message: message);
      final result = await _repository(
        transport: _Transport(responses: [cause]),
      ).readServers(scope: scope) as PluginMcpInventoryReadFailed;
      expect(result.cause, same(cause));
    });
  }
}

import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/models/open_code_mcp_login_challenge.dart";
import "package:opencode_plugin/src/open_code_raw_http_client.dart";
import "package:opencode_plugin/src/v2/api/opencode_v2_api.dart";
import "package:opencode_plugin/src/v2/models/v2_mcp_authentication.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_repository.dart";
import "package:opencode_plugin/src/v2/repositories/v2_message_mapper.dart";
import "package:opencode_plugin/src/v2/repositories/v2_model_mapper.dart";
import "package:opencode_plugin/src/v2/services/v2_mcp_authentication_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _directory = "/fixture/project";
const _target = PluginMcpServerTarget(
  scope: PluginMcpProjectScope(projectId: _directory),
  serverKey: "fixture",
);
const _authorization =
    "https://fixture.invalid/authorize?state=fixture-state&redirect_uri=http%3A%2F%2F127.0.0.1%3A3456%2Fcallback";
final _callback = Uri.parse("http://127.0.0.1:3456/callback?state=fixture-state&code=fixture-code");

http.Response _data({required Object data}) => http.Response(jsonEncode({"data": data}), 200);
http.Response _attempt({required String mode}) => _data(
  data: {
    "attemptID": "attempt-fixture",
    "url": _authorization,
    "mode": mode,
    "instructions": "Fixture",
    "time": {"created": 1, "expires": 2},
  },
);

class _Fixture({required final Future<http.Response>? Function(http.Request)? override}) {
  final calls = <http.Request>[];
  String status = "pending";
  bool removed = false;
  bool hasIntegration = true;
  List<Map<String, Object>> connections = [];
  late final MockClient client;
  late final V2McpAuthenticationService service;

  this {
    client = MockClient((request) async {
      calls.add(request);
      final custom = override?.call(request);
      if (custom != null) return await custom;
      if (request.url.port == 3456) {
        expect(request.headers["Authorization"], isNull);
        expect(request.followRedirects, isFalse);
        return http.Response("Fixture callback accepted", 200);
      }
      expect(request.url.queryParameters, {"location[directory]": _directory});
      expect(request.headers["Authorization"], isNotNull);
      if (request.url.path == "/api/mcp") {
        return _data(
          data: [
            {
              "name": "fixture",
              "status": {"status": "connected"},
              if (hasIntegration) "integrationID": "native-integration",
            },
          ],
        );
      }
      if (request.url.path == "/api/integration/native-integration") {
        return _data(
          data: {
            "id": "native-integration",
            "name": "Fixture",
            "methods": [
              {"id": "native-method", "type": "oauth", "label": "Fixture"},
            ],
            "connections": connections,
          },
        );
      }
      if (request.method == "POST") {
        expect(jsonDecode(request.body), {"methodID": "native-method"});
        return _attempt(mode: "auto");
      }
      if (request.method == "DELETE") {
        if (request.url.path.contains("/connect/oauth/")) removed = true;
        return http.Response("", 204);
      }
      expect(request.url.path, "/api/integration/native-integration/connect/oauth/attempt-fixture");
      if (removed) {
        return http.Response(
          jsonEncode({
            "_tag": "IntegrationAttemptNotFoundError",
            "integrationID": "native-integration",
            "attemptID": "attempt-fixture",
            "message": "Fixture attempt not found",
          }),
          404,
        );
      }
      return _data(
        data: {
          "status": status,
          "time": {"created": 1, "expires": 2},
          if (status == "failed") "message": "Fixture rejection",
        },
      );
    });
    final repository = OpenCodeV2Repository(
      api: OpenCodeV2Api(
        client: OpenCodeRawHttpClient(serverURL: "http://localhost:4096", password: "fixture", client: client),
      ),
      modelMapper: const V2ModelMapper(pluginId: "fixture"),
      messageMapper: const V2MessageMapper(),
    );
    service = V2McpAuthenticationService(repository: repository, pollInterval: const Duration(milliseconds: 1));
    addTearDown(() async {
      await service.dispose();
      client.close();
    });
  }

  Future<PluginMcpCancelableAuthentication> begin() async =>
      await service.begin(directory: _directory, target: _target) as PluginMcpCancelableAuthentication;
}

class _Observation({required final PluginMcpCancelableAuthentication operation}) {
  final events = <PluginMcpAuthenticationEvent>[];
  final challenge = Completer<PluginMcpAuthenticationChallenge>();
  final terminal = Completer<PluginMcpAuthenticationEvent>();
  final done = Completer<void>();
  this {
    final subscription = operation.events.listen((event) {
      events.add(event);
      if (event is PluginMcpAuthenticationChallenge) {
        challenge.complete(event);
      } else {
        terminal.complete(event);
      }
    }, onDone: done.complete);
    addTearDown(subscription.cancel);
  }
}

void main() {
  test("OAuth diagnostic redaction preserves endpoint and non-secret context", () {
    expect(
      redactMcpOAuthQuerySecrets(
        message:
            "Rejected https://fixture.invalid/callback?code=secret-code&state=secret-state&reason=denied "
            "http://localhost/token?access_token=secret-access&refresh_token=secret-refresh&client_secret=secret-client",
      ),
      "Rejected https://fixture.invalid/callback?code=[redacted]&state=[redacted]&reason=denied "
      "http://localhost/token?access_token=[redacted]&refresh_token=[redacted]&client_secret=[redacted]",
    );
  });

  test("cancel before subscription discards preparation without native mutation", () async {
    final fixture = _Fixture(override: null);
    final operation = await fixture.begin();
    await operation.cancel();
    final observation = _Observation(operation: operation);
    await observation.done.future;
    expect(observation.events, isEmpty);
    expect(fixture.calls.map((request) => request.method), ["GET", "GET"]);
  });

  test("runtime retirement waits for an in-flight start and cleans its returned handle", () async {
    final response = Completer<http.Response>();
    final starting = Completer<void>();
    final fixture = _Fixture(
      override: (request) {
        if (request.method != "POST") return null;
        starting.complete();
        return response.future;
      },
    );
    final observation = _Observation(operation: await fixture.begin());
    await starting.future;
    var retired = false;
    final retirement = fixture.service.dispose().then((_) => retired = true);
    await observation.done.future;
    expect(retired, isFalse);
    response.complete(_attempt(mode: "auto"));
    await retirement;
    expect(fixture.removed, isTrue);
    expect(observation.events, [isA<PluginMcpAuthenticationFailed>()]);
  });

  test("confirmed native removal outside cancellation settles as unresolved failure", () async {
    final fixture = _Fixture(override: null);
    final observation = _Observation(operation: await fixture.begin());
    await observation.challenge.future;
    fixture.removed = true;
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationFailed>());
    await observation.done.future;
  });

  test("polling removal during DELETE waits for cancellation acknowledgement", () async {
    final response = Completer<http.Response>();
    final deleting = Completer<void>();
    final removalRead = Completer<void>();
    final fixture = _Fixture(
      override: (request) {
        if (request.method == "DELETE") {
          deleting.complete();
          return response.future;
        }
        if (deleting.isCompleted && request.method == "GET" && !removalRead.isCompleted) removalRead.complete();
        return null;
      },
    );
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    await observation.challenge.future;
    final cancellation = operation.cancel();
    await deleting.future;
    fixture.removed = true;
    await removalRead.future;
    expect(observation.terminal.isCompleted, isFalse);
    response.complete(http.Response("", 204));
    await cancellation;
    await observation.done.future;
    expect(observation.terminal.isCompleted, isFalse);
  });

  test("removal after a persisting cancellation settles as unresolved failure", () async {
    final cancelled = Completer<void>();
    final persisting = Completer<void>();
    final fixture = _Fixture(
      override: (request) {
        if (request.method == "DELETE") {
          cancelled.complete();
          return Future.value(http.Response("", 204));
        }
        if (cancelled.isCompleted && request.method == "GET" && !persisting.isCompleted) {
          persisting.complete();
          return Future.value(
            _data(
              data: {
                "status": "pending",
                "time": {"created": 1, "expires": 2},
              },
            ),
          );
        }
        return null;
      },
    );
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    await observation.challenge.future;
    final cancellation = operation.cancel();
    await persisting.future;
    fixture.removed = true;
    await cancellation;
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationFailed>());
    await observation.done.future;
  });

  for (final cleanupFails in [false, true]) {
    test("runtime retirement stops callback access and records cleanup outcome: $cleanupFails", () async {
      final fixture = _Fixture(
        override: (request) => cleanupFails && request.method == "DELETE"
            ? Future.value(http.Response("Fixture cleanup unavailable", 503))
            : null,
      );
      final operation = await fixture.begin();
      final observation = _Observation(operation: operation);
      await observation.challenge.future;
      await fixture.service.dispose();
      expect(await observation.terminal.future, isA<PluginMcpAuthenticationFailed>());
      await observation.done.future;
      expect(fixture.removed, !cleanupFails);
      await expectLater(
        operation.submitCallback(callbackUri: _callback),
        throwsA(isA<PluginMcpAuthenticationCallbackRejectedException>()),
      );
    });
  }

  for (final methods in <List<Map<String, Object>>>[
    [],
    [
      {"id": "native-key", "type": "key", "label": "Fixture"},
    ],
    [
      {
        "id": "native-method",
        "type": "oauth",
        "label": "Fixture",
        "form": <Object>[],
      },
    ],
  ]) {
    test("native method eligibility is validated before start: $methods", () async {
      final fixture = _Fixture(
        override: (request) {
          if (request.url.path != "/api/integration/native-integration") return null;
          return Future.value(
            _data(data: {"id": "native-integration", "name": "Fixture", "methods": methods, "connections": <Object>[]}),
          );
        },
      );
      await expectLater(fixture.begin(), throwsA(isA<PluginMcpAuthenticationUnavailableException>()));
      expect(fixture.calls.any((request) => request.method == "POST"), isFalse);
    });
  }

  test("explicit native start rejection closes with failure", () async {
    final fixture = _Fixture(
      override: (request) => request.method == "POST" ? Future.value(http.Response("Fixture rejection", 400)) : null,
    );
    final observation = _Observation(operation: await fixture.begin());
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationFailed>());
    await observation.done.future;
  });

  test("unknown and failed status reads retain ownership before later native completion", () async {
    final statusRead = Completer<void>();
    var reads = 0;
    final fixture = _Fixture(
      override: (request) {
        if (request.method != "GET" || !request.url.path.contains("/connect/oauth/")) return null;
        reads++;
        if (reads == 1) {
          return Future.value(
            _data(
              data: {
                "status": "future",
                "time": {"created": 1, "expires": 2},
              },
            ),
          );
        }
        if (reads == 2) {
          statusRead.complete();
          return Future.value(http.Response("Fixture temporary failure", 503));
        }
        return null;
      },
    );
    final observation = _Observation(operation: await fixture.begin());
    await statusRead.future;
    expect(observation.done.isCompleted, isFalse);
    fixture.status = "complete";
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationCompleted>());
    await observation.done.future;
  });

  test("preparation is read-only and discarding it starts no attempt", () async {
    final fixture = _Fixture(override: null);
    await fixture.begin();
    expect(fixture.calls.map((request) => request.method), ["GET", "GET"]);
  });

  test("missing native integration rejects before a native mutation", () async {
    final fixture = _Fixture(override: null)..hasIntegration = false;
    await expectLater(
      fixture.begin(),
      throwsA(
        isA<PluginMcpAuthenticationUnavailableException>().having(
          (error) => error.reason,
          "reason",
          PluginMcpAuthenticationUnavailableReason.notSupported,
        ),
      ),
    );
    expect(fixture.calls, hasLength(1));
  });

  test("callback ACK preserves pending until native completion", () async {
    final fixture = _Fixture(override: null);
    final operation = await fixture.begin();
    expect(operation.effectScope, PluginMcpActionEffectScope.harness);
    final observation = _Observation(operation: operation);
    await observation.challenge.future;
    await operation.submitCallback(callbackUri: _callback);
    expect(observation.terminal.isCompleted, isFalse);
    fixture.status = "complete";
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationCompleted>());
    await observation.done.future;
    await expectLater(
      operation.submitCallback(callbackUri: _callback),
      throwsA(isA<PluginMcpAuthenticationCallbackRejectedException>()),
    );
  });

  for (final (status, reason) in [
    ("failed", PluginMcpAuthenticationFailureReason.nativeFailure),
    ("expired", PluginMcpAuthenticationFailureReason.expired),
  ]) {
    test("native $status is the authoritative terminal result", () async {
      final fixture = _Fixture(override: null)..status = status;
      final observation = _Observation(operation: await fixture.begin());
      final event = await observation.terminal.future as PluginMcpAuthenticationFailed;
      expect(event.reason, reason);
      await observation.done.future;
    });
  }

  test("native cancellation confirms attempt removal, without credential deletion", () async {
    final fixture = _Fixture(override: null);
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    await observation.challenge.future;
    await operation.cancel();
    await observation.done.future;
    expect(observation.terminal.isCompleted, isFalse);
    expect(
      fixture.calls.where((request) => request.method == "DELETE").single.url.path,
      "/api/integration/native-integration/connect/oauth/attempt-fixture",
    );
  });

  test("cancel during start waits for the returned native handle", () async {
    final response = Completer<http.Response>();
    final starting = Completer<void>();
    final fixture = _Fixture(
      override: (request) {
        if (request.method != "POST") return null;
        starting.complete();
        return response.future;
      },
    );
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    await starting.future;
    final cancellation = operation.cancel();
    expect(fixture.calls.any((request) => request.method == "DELETE"), isFalse);
    response.complete(_attempt(mode: "auto"));
    await cancellation;
    await observation.done.future;
    expect(fixture.removed, isTrue);
  });

  test("native persisting no-op cancellation yields the eventual completed result", () async {
    final deleting = Completer<void>();
    final fixture = _Fixture(
      override: (request) {
        if (request.method != "DELETE") return null;
        deleting.complete();
        return Future.value(http.Response("", 204));
      },
    );
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    await observation.challenge.future;
    var cancelled = false;
    final cancellation = operation.cancel().then((_) => cancelled = true);
    await deleting.future;
    expect(cancelled, isFalse);
    fixture.status = "complete";
    await cancellation;
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationCompleted>());
    await observation.done.future;
  });

  test("failed native cancellation retains observation until native settlement", () async {
    final fixture = _Fixture(
      override: (request) =>
          request.method == "DELETE" ? Future.value(http.Response("Fixture unavailable", 503)) : null,
    );
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    await observation.challenge.future;
    await expectLater(operation.cancel(), throwsA(isA<OpenCodeApiException>()));
    expect(observation.done.isCompleted, isFalse);
    fixture.status = "complete";
    await observation.terminal.future;
    await observation.done.future;
  });

  for (final body in ["not JSON", '''{"data":{}}''']) {
    test("uncertain start retains ownership until runtime retirement: $body", () async {
      final started = Completer<void>();
      final fixture = _Fixture(
        override: (request) {
          if (request.method != "POST") return null;
          started.complete();
          return Future.value(http.Response(body, 200));
        },
      );
      final operation = await fixture.begin();
      final observation = _Observation(operation: operation);
      await started.future;
      await expectLater(operation.cancel(), throwsA(isA<V2McpAuthenticationException>()));
      expect(observation.done.isCompleted, isFalse);
      await fixture.service.dispose();
      expect(await observation.terminal.future, isA<PluginMcpAuthenticationFailed>());
      await observation.done.future;
      expect(fixture.calls.where((request) => request.method == "POST"), hasLength(1));
    });
  }

  test("invalid native challenge is cancelled using its retained handle", () async {
    final fixture = _Fixture(
      override: (request) => request.method == "POST" ? Future.value(_attempt(mode: "code")) : null,
    );
    final observation = _Observation(operation: await fixture.begin());
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationFailed>());
    await observation.done.future;
    expect(fixture.removed, isTrue);
  });

  test("forget reads current native credential IDs and excludes environment connections", () async {
    final fixture = _Fixture(override: null)
      ..connections = [
        {"type": "credential", "id": "fresh/credential", "label": "Fixture"},
        {"type": "env", "name": "FIXTURE_TOKEN"},
      ];
    expect(await fixture.service.forget(directory: _directory, target: _target), PluginMcpActionEffectScope.harness);
    expect(fixture.calls.where((request) => request.method == "DELETE").single.url.pathSegments, [
      "api",
      "credential",
      "fresh/credential",
    ]);
    expect(fixture.calls.where((request) => request.url.path == "/api/credential"), isEmpty);
  });

  for (final callback in [
    "http://127.0.0.1:3457/callback?state=fixture-state&code=fixture",
    "http://127.0.0.1:3456/other?state=fixture-state&code=fixture",
    "http://127.0.0.1:3456/callback?state=other&code=fixture",
    "http://127.0.0.1:3456/callback?state=fixture-state&state=other&code=fixture",
    "http://127.0.0.1:3456/callback?state=fixture-state&code=fixture&error=denied",
    "http://127.0.0.1:3456/callback?state=fixture-state&code=fixture&error=",
    "http://127.0.0.1:3456/callback?state=fixture-state&code=&error=denied",
    "http://127.0.0.1:3456/callback?state=fixture-state&code=fixture#fragment",
  ]) {
    test("rejects callback mismatch without HTTP: $callback", () async {
      final fixture = _Fixture(override: null);
      final operation = await fixture.begin();
      final observation = _Observation(operation: operation);
      await observation.challenge.future;
      await expectLater(
        operation.submitCallback(callbackUri: Uri.parse(callback)),
        throwsA(isA<PluginMcpAuthenticationCallbackRejectedException>()),
      );
      expect(fixture.calls.any((request) => request.url.port == 3456), isFalse);
      await operation.cancel();
      await observation.done.future;
    });
  }
}

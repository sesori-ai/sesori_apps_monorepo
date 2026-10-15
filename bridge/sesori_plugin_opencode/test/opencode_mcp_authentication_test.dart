import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/active_session_tracker.dart";
import "package:opencode_plugin/src/models/open_code_mcp_authentication_dto.dart";
import "package:opencode_plugin/src/open_code_raw_http_client.dart";
import "package:opencode_plugin/src/opencode_api.dart";
import "package:opencode_plugin/src/opencode_repository.dart";
import "package:opencode_plugin/src/opencode_service.dart";
import "package:opencode_plugin/src/services/open_code_mcp_authentication_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _directory = "/fixture/项目";
const _name = "fixture/server?name";
const _target = PluginMcpServerTarget(
  scope: PluginMcpProjectScope(projectId: _directory),
  serverKey: _name,
);
const _authorization =
    "https://fixture.invalid/authorize?state=fixture-state&redirect_uri=http%3A%2F%2F127.0.0.1%3A3456%2Fcallback";
final _callback = Uri.parse("http://127.0.0.1:3456/callback?state=fixture-state&code=fixture-code");

class _Fixture({required final Future<http.Response>? Function(http.Request)? override}) {
  final calls = <http.Request>[];
  String transport = "remote";
  Object? oauth = {"clientSecret": "fixture-sensitive"};
  String status = "needs_auth";
  String callbackStatus = "connected";
  bool present = true;
  late final OpenCodeApi api;
  late final OpenCodeMcpAuthenticationService authentication;
  late final OpenCodeService service;
  late final MockClient client;

  this {
    client = MockClient((request) async {
      calls.add(request);
      expect(request.url.port, 4096);
      expect(request.headers["x-opencode-directory"], Uri.encodeFull(_directory));
      final custom = override?.call(request);
      if (custom != null) return await custom;
      if (request.url.path == "/mcp") {
        return http.Response(
          jsonEncode({
            if (present) _name: {"status": status, "error": "Fixture native diagnostic"},
          }),
          200,
        );
      }
      if (request.url.path == "/config") {
        return http.Response(
          jsonEncode({
            "mcp": {
              if (present)
                _name: {
                  "type": transport,
                  "url": "https://fixture.invalid/mcp",
                  "oauth": oauth,
                  "headers": {"authorization": "fixture-sensitive"},
                },
            },
          }),
          200,
        );
      }
      expect(request.url.pathSegments.take(3), ["mcp", _name, "auth"]);
      if (request.method == "DELETE") return http.Response('{"success":true}', 200);
      expect(request.method, "POST");
      if (request.url.pathSegments.last == "callback") {
        expect(jsonDecode(request.body), {"code": "fixture-code"});
        return http.Response(jsonEncode({"status": callbackStatus, "error": "Fixture rejection"}), 200);
      }
      expect(request.body, isEmpty);
      return http.Response(jsonEncode({"authorizationUrl": _authorization, "oauthState": "fixture-state"}), 200);
    });
    api = OpenCodeApi(
      client: OpenCodeRawHttpClient(serverURL: "http://localhost:4096", password: null, client: client),
    );
    final repository = OpenCodeRepository(api);
    service = OpenCodeService(repository, ActiveSessionTracker(repository));
    authentication = OpenCodeMcpAuthenticationService(service: service, repository: repository);
    addTearDown(() async {
      await authentication.dispose();
      await service.dispose();
      client.close();
    });
  }

  Future<PluginMcpNativeSettlementAuthentication> begin() async =>
      await authentication.begin(target: _target) as PluginMcpNativeSettlementAuthentication;
}

class _Observation({required final PluginMcpNativeSettlementAuthentication operation}) {
  final challenge = Completer<PluginMcpAuthenticationChallenge>();
  final terminal = Completer<PluginMcpAuthenticationEvent>();
  final done = Completer<void>();
  this {
    final subscription = operation.events.listen((event) {
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
  test("minimal configuration decoding discards OAuth secrets and unknown fields", () async {
    final fixture = _Fixture(override: null);
    final server = (await fixture.api.getMcpConfiguration(directory: _directory)).mcp[_name]!;
    expect(server.transport, OpenCodeMcpTransport.remote);
    expect(server.oauthEnabled, isTrue);
    expect(server.toString(), isNot(contains("fixture-sensitive")));
  });

  test("preparation is read-only and the native operation has no cancellation method", () async {
    final fixture = _Fixture(override: null);
    final operation = await fixture.begin();
    expect(operation.effectScope, PluginMcpActionEffectScope.harness);
    expect(fixture.calls.every((request) => request.method == "GET"), isTrue);
    expect(fixture.calls, hasLength(2));
  });

  test("native manual callback settles without an HTTP request to the loopback URI", () async {
    final fixture = _Fixture(override: null);
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    final challenge = await observation.challenge.future;
    expect(challenge.expectedCallbackUri.port, 3456);
    expect(observation.terminal.isCompleted, isFalse);
    await operation.submitCallback(callbackUri: _callback);
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationCompleted>());
    await observation.done.future;
    expect(fixture.calls.where((request) => request.method == "POST").map((request) => request.url.pathSegments.last), [
      "auth",
      "callback",
    ]);
    expect(fixture.calls.any((request) => request.method == "DELETE"), isFalse);
  });

  test("native callback failure is terminal after the native method returns", () async {
    final fixture = _Fixture(override: null)..callbackStatus = "failed";
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    await observation.challenge.future;
    await operation.submitCallback(callbackUri: _callback);
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationFailed>());
    await observation.done.future;
  });

  test("the native no-challenge sentinel maps to explicit already-authorized completion", () async {
    final fixture = _Fixture(
      override: (request) => request.method == "POST"
          ? Future.value(http.Response('{"authorizationUrl":"","oauthState":"fixture-state"}', 200))
          : null,
    );
    final observation = _Observation(operation: await fixture.begin());
    expect(await observation.terminal.future, isA<PluginMcpAuthenticationCompleted>());
    expect(observation.challenge.isCompleted, isFalse);
    await observation.done.future;
  });

  for (final (transport, oauth, status, reason)
      in <(String, Object?, String, PluginMcpAuthenticationUnavailableReason)>[
        ("local", null, "connected", PluginMcpAuthenticationUnavailableReason.notSupported),
        ("future", null, "connected", PluginMcpAuthenticationUnavailableReason.notSupported),
        ("remote", false, "connected", PluginMcpAuthenticationUnavailableReason.notSupported),
        (
          "remote",
          null,
          "needs_client_registration",
          PluginMcpAuthenticationUnavailableReason.nativeConfigurationRequired,
        ),
      ]) {
    test("native eligibility excludes $transport/$oauth/$status before start", () async {
      final fixture = _Fixture(override: null)
        ..transport = transport
        ..oauth = oauth
        ..status = status;
      await expectLater(
        fixture.begin(),
        throwsA(isA<PluginMcpAuthenticationUnavailableException>().having((error) => error.reason, "reason", reason)),
      );
      expect(fixture.calls.every((request) => request.method == "GET"), isTrue);
    });
  }

  test("missing target rejects before mutation", () async {
    final fixture = _Fixture(override: null)..present = false;
    await expectLater(
      fixture.begin(),
      throwsA(
        isA<PluginMcpAuthenticationUnavailableException>().having(
          (error) => error.reason,
          "reason",
          PluginMcpAuthenticationUnavailableReason.targetNotFound,
        ),
      ),
    );
  });

  test("harness scope rejects without selecting a directory or issuing native work", () async {
    final fixture = _Fixture(override: null);
    await expectLater(
      fixture.authentication.begin(
        target: const PluginMcpServerTarget(scope: PluginMcpHarnessScope(), serverKey: _name),
      ),
      throwsA(isA<PluginMcpAuthenticationUnavailableException>()),
    );
    expect(fixture.calls, isEmpty);
  });

  for (final (code, body) in [
    (500, "Fixture native server error"),
    (200, "malformed"),
    (200, '{"authorizationUrl":"$_authorization","oauthState":"different"}'),
  ]) {
    test("uncertain start retains ownership without DELETE credentials: $code/$body", () async {
      final started = Completer<void>();
      final fixture = _Fixture(
        override: (request) {
          if (request.method != "POST") return null;
          started.complete();
          return Future.value(http.Response(body, code));
        },
      );
      final observation = _Observation(operation: await fixture.begin());
      await started.future;
      expect(observation.done.isCompleted, isFalse);
      await fixture.authentication.dispose();
      await observation.done.future;
      expect(fixture.calls.any((request) => request.method == "DELETE"), isFalse);
      expect(fixture.calls.where((request) => request.method == "POST"), hasLength(1));
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

  for (final callback in [
    "http://127.0.0.1:3457/callback?state=fixture-state&code=fixture-code",
    "http://127.0.0.1:3456/callback?state=other&code=fixture-code",
    "http://127.0.0.1:3456/callback?state=fixture-state&error=access_denied",
  ]) {
    test("invalid/unsupported callback retains ownership without native cleanup: $callback", () async {
      final fixture = _Fixture(override: null);
      final operation = await fixture.begin();
      final observation = _Observation(operation: operation);
      await observation.challenge.future;
      await expectLater(
        operation.submitCallback(callbackUri: Uri.parse(callback)),
        throwsA(isA<PluginMcpAuthenticationCallbackRejectedException>()),
      );
      expect(observation.done.isCompleted, isFalse);
      expect(fixture.calls.where((request) => request.method == "POST"), hasLength(1));
      await fixture.authentication.dispose();
      await observation.done.future;
      expect(fixture.calls.any((request) => request.method == "DELETE"), isFalse);
    });
  }

  test("unknown callback outcome remains uncertain until runtime retirement", () async {
    final fixture = _Fixture(override: null)..callbackStatus = "future";
    final operation = await fixture.begin();
    final observation = _Observation(operation: operation);
    await observation.challenge.future;
    await expectLater(operation.submitCallback(callbackUri: _callback), throwsA(isA<Exception>()));
    expect(observation.done.isCompleted, isFalse);
    await fixture.authentication.dispose();
    await observation.done.future;
  });

  test("forget resolves fresh native target and uses the harness credential command only", () async {
    final fixture = _Fixture(override: null);
    expect(await fixture.authentication.forget(target: _target), PluginMcpActionEffectScope.harness);
    expect(fixture.calls.where((request) => request.method == "DELETE").single.url.pathSegments, [
      "mcp",
      _name,
      "auth",
    ]);
    fixture.present = false;
    await expectLater(
      fixture.authentication.forget(target: _target),
      throwsA(isA<PluginMcpAuthenticationUnavailableException>()),
    );
    expect(fixture.calls.where((request) => request.method == "DELETE"), hasLength(1));
  });
}

import "dart:async";
import "dart:convert";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/open_code_raw_http_client.dart";
import "package:opencode_plugin/src/v2/api/opencode_v2_api.dart";
import "package:opencode_plugin/src/v2/models/openapi/connection_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/integration_attempt_encoded.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/integration_attempt_status.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/integration_method.g.dart";
import "package:opencode_plugin/src/v2/models/v2_decode_exception.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _directory = "/fixture/项目";
const _integrationId = "native/integration?fixture";
const _attemptId = "native/attempt?fixture";
const _credentialId = "native/credential?fixture";
const _time = {"created": 1, "expires": 2};

OpenCodeV2Api _api({required Future<http.Response> Function(http.Request) handler}) {
  final client = MockClient((request) {
    expect(request.url.queryParameters, {"location[directory]": _directory});
    return handler(request);
  });
  addTearDown(client.close);
  return OpenCodeV2Api(
    client: OpenCodeRawHttpClient(serverURL: "http://localhost:4096", password: null, client: client),
  );
}

http.Response _data({required Object data}) => http.Response(jsonEncode({"data": data}), 200);

void main() {
  test("reads declared OAuth method and secret-free credential IDs without listing credentials", () async {
    final api = _api(
      handler: (request) async {
        expect(request.method, "GET");
        expect(request.url.pathSegments, ["api", "integration", _integrationId]);
        return _data(
          data: {
            "id": _integrationId,
            "name": "Fixture",
            "methods": [
              {"id": "native-method", "type": "oauth", "label": "Sign in"},
            ],
            "connections": [
              {"type": "credential", "id": _credentialId, "label": "Fixture"},
              {"type": "env", "name": "FIXTURE_TOKEN"},
            ],
          },
        );
      },
    );
    final result = await api.getMcpIntegration(directory: _directory, integrationId: _integrationId);
    expect(result.id, _integrationId);
    expect(switch (result.methods.single) {
      IntegrationOAuthMethod(:final id) => id,
      IntegrationCommandMethod() ||
      IntegrationKeyMethod() ||
      IntegrationEnvMethod() ||
      IntegrationMethodUnknown() => null,
    }, "native-method");
    expect((result.connections.first as ConnectionCredentialInfo).id, _credentialId);
    expect((result.connections.first as ConnectionCredentialInfo).method, isNull);
    expect(switch (result.connections.last) {
      ConnectionEnvInfo() => true,
      ConnectionCredentialInfo() || ConnectionInfoUnknown() => false,
    }, isTrue);
  });

  test("starts only the native declared method and decodes the attempt handle", () async {
    final api = _api(
      handler: (request) async {
        expect(request.method, "POST");
        expect(request.url.pathSegments, ["api", "integration", _integrationId, "connect", "oauth"]);
        expect(request.headers["content-type"], "application/json");
        expect(jsonDecode(request.body), {"methodID": "native-method"});
        return _data(
          data: {
            "attemptID": _attemptId,
            "url": "https://fixture.invalid/authorize",
            "instructions": "Continue in your browser",
            "mode": "auto",
            "time": _time,
          },
        );
      },
    );
    final result = await api.startMcpAuthentication(
      directory: _directory,
      integrationId: _integrationId,
      methodId: "native-method",
    );
    expect(result.attemptID, _attemptId);
    expect(result.mode, IntegrationAttemptEncodedMode.auto);
    expect(result.url, "https://fixture.invalid/authorize");
  });

  for (final (status, matcher) in [
    ("pending", isA<IntegrationAttemptStatusPending>()),
    ("complete", isA<IntegrationAttemptStatusComplete>()),
    ("failed", isA<IntegrationAttemptStatusFailed>()),
    ("expired", isA<IntegrationAttemptStatusExpired>()),
    ("future", isA<IntegrationAttemptStatusUnknown>()),
  ]) {
    test("observes native $status without inferring completion", () async {
      final api = _api(
        handler: (request) async {
          expect(request.method, "GET");
          expect(request.url.pathSegments, ["api", "integration", _integrationId, "connect", "oauth", _attemptId]);
          return _data(data: {"status": status, "time": _time, if (status == "failed") "message": "Fixture denial"});
        },
      );
      final result = await api.getMcpAuthenticationStatus(
        directory: _directory,
        integrationId: _integrationId,
        attemptId: _attemptId,
      );
      expect(result, matcher);
      expect(switch (result) {
        IntegrationAttemptStatusPending() => "pending",
        IntegrationAttemptStatusComplete() => "complete",
        IntegrationAttemptStatusFailed() => "failed",
        IntegrationAttemptStatusExpired() => "expired",
        IntegrationAttemptStatusUnknown() => "future",
      }, status);
      if (result is IntegrationAttemptStatusFailed) expect(result.message, "Fixture denial");
    });
  }

  test("cancellation and forgetting use distinct native DELETE targets", () async {
    final calls = <List<String>>[];
    final api = _api(
      handler: (request) async {
        expect(request.method, "DELETE");
        expect(request.body, isEmpty);
        calls.add(request.url.pathSegments);
        return http.Response("", 204);
      },
    );
    await api.cancelMcpAuthentication(directory: _directory, integrationId: _integrationId, attemptId: _attemptId);
    await api.removeMcpCredential(directory: _directory, credentialId: _credentialId);
    expect(calls, [
      ["api", "integration", _integrationId, "connect", "oauth", _attemptId],
      ["api", "credential", _credentialId],
    ]);
  });

  for (final body in ["not json", '{"data":{"status":"pending"}}']) {
    test("malformed native status retains its decode cause: $body", () async {
      final api = _api(handler: (_) async => http.Response(body, 200));
      await expectLater(
        api.getMcpAuthenticationStatus(directory: _directory, integrationId: _integrationId, attemptId: _attemptId),
        throwsA(isA<V2DecodeException>().having((error) => error.innerError, "cause", isNotNull)),
      );
    });
  }

  test("native transport failure propagates unchanged", () async {
    const error = PluginOperationException("fixture", message: "Fixture failure", statusCode: 503);
    final api = _api(handler: (_) async => throw error);
    await expectLater(
      api.startMcpAuthentication(directory: _directory, integrationId: _integrationId, methodId: "native-method"),
      throwsA(same(error)),
    );
  });

  test("native start stays pending beyond the ordinary response budget", () {
    fakeAsync((clock) {
      final response = Completer<http.Response>();
      final api = _api(handler: (_) => response.future);
      var completed = false;
      unawaited(
        api
            .startMcpAuthentication(
              directory: _directory,
              integrationId: _integrationId,
              methodId: "native-method",
            )
            .then((_) => completed = true),
      );
      clock.elapse(const Duration(minutes: 4));
      expect(completed, isFalse);
      response.complete(
        _data(
          data: {
            "attemptID": _attemptId,
            "url": "https://fixture.invalid/authorize",
            "instructions": "Continue",
            "mode": "auto",
            "time": _time,
          },
        ),
      );
      clock.flushMicrotasks();
      expect(completed, isTrue);
    });
  });
}

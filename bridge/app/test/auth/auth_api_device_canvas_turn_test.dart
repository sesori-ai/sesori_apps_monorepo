import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/auth_api.dart";
import "package:sesori_bridge/src/foundation/abortable_request.dart";
import "package:test/test.dart";

void main() {
  group("AuthApi.issueDeviceCanvasTurnCredentials", () {
    test("posts the bounded stream context with bearer auth and parses the response", () async {
      _SentRequest? sent;
      final client = http.Client();
      addTearDown(client.close);
      final expiresAt = DateTime.utc(2026, 8, 27, 12, 5).millisecondsSinceEpoch;
      final api = AuthApi(
        authBackendUrl: "https://api.example.test",
        client: client,
        requestDeadline: AuthApi.defaultRequestDeadline,
        sendRequest:
            ({
              required client,
              required method,
              required url,
              headers,
              body,
              required deadline,
              required maxResponseBytes,
            }) async {
              sent = _SentRequest(method: method, url: url, headers: headers, body: body, deadline: deadline);
              expect(maxResponseBytes, 32768);
              return http.Response(
                jsonEncode({
                  "urls": ["turn:turn.example.test:3478?transport=udp"],
                  "username": "${expiresAt ~/ Duration.millisecondsPerSecond}:operation_1",
                  "credential": base64Encode(List<int>.filled(20, 1)),
                  "expiresAt": expiresAt,
                }),
                200,
              );
            },
      );

      final result = await api.issueDeviceCanvasTurnCredentials(
        bridgeId: "br_server001",
        operationId: "operation_1",
        leaseExpiresAt: expiresAt + const Duration(minutes: 5).inMilliseconds,
        accessToken: "access-token",
      );

      expect(result.expiresAt, expiresAt);
      expect(sent?.method, "POST");
      expect(sent?.url, Uri.parse("https://api.example.test/device-canvas/turn-credentials"));
      expect(sent?.headers?["Authorization"], "Bearer access-token");
      expect(sent?.headers?["Content-Type"], "application/json");
      expect(sent?.deadline, const Duration(seconds: 10));
      expect(
        jsonDecode(sent!.body!) as Map<String, dynamic>,
        {
          "bridgeId": "br_server001",
          "operationId": "operation_1",
          "leaseExpiresAt": expiresAt + const Duration(minutes: 5).inMilliseconds,
        },
      );
    });

    test("returns bounded exceptions without retaining response credentials", () async {
      const sensitive = "credential-that-must-not-be-retained";
      final client = http.Client();
      addTearDown(client.close);
      var response = http.Response(sensitive, 503);
      final api = AuthApi(
        authBackendUrl: "https://api.example.test",
        client: client,
        requestDeadline: AuthApi.defaultRequestDeadline,
        sendRequest: ({
          required client,
          required method,
          required url,
          headers,
          body,
          required deadline,
          required maxResponseBytes,
        }) async => response,
      );

      final rejected = await _captureError(api);
      expect(rejected, isA<DeviceCanvasTurnApiException>());
      expect((rejected as DeviceCanvasTurnApiException).statusCode, 503);
      expect(rejected.toString(), isNot(contains(sensitive)));

      response = http.Response("{not-json", 200);
      final malformed = await _captureError(api);
      expect(malformed, isA<DeviceCanvasTurnApiException>());
      expect((malformed as DeviceCanvasTurnApiException).statusCode, 200);
      expect(malformed.toString(), isNot(contains("not-json")));
    });

    test("rejects fractional expiry values and unknown response fields", () async {
      final client = http.Client();
      addTearDown(client.close);
      late String responseBody;
      final api = AuthApi(
        authBackendUrl: "https://api.example.test",
        client: client,
        requestDeadline: AuthApi.defaultRequestDeadline,
        sendRequest: ({
          required client,
          required method,
          required url,
          headers,
          body,
          required deadline,
          required maxResponseBytes,
        }) async => http.Response(responseBody, 200),
      );
      final validPayload = {
        "urls": ["turn:turn.example.test:3478?transport=udp"],
        "username": "1:operation_1",
        "credential": base64Encode(List<int>.filled(20, 1)),
        "expiresAt": 1000,
      };

      responseBody = jsonEncode({...validPayload, "expiresAt": 1000.5});
      await expectLater(_captureError(api), completion(isA<DeviceCanvasTurnApiException>()));

      responseBody = jsonEncode({...validPayload, "unexpected": true});
      await expectLater(_captureError(api), completion(isA<DeviceCanvasTurnApiException>()));
    });

    test("aborts oversized streamed responses before retaining their bodies", () async {
      final client = _OversizedResponseClient();
      addTearDown(client.close);
      final api = AuthApi(
        authBackendUrl: "https://api.example.test",
        client: client,
        requestDeadline: AuthApi.defaultRequestDeadline,
        sendRequest: sendRequestWithDeadline,
      );

      final error = await _captureError(api);

      expect(error, isA<DeviceCanvasTurnApiException>());
      expect((error as DeviceCanvasTurnApiException).statusCode, 503);
      expect(error.toString(), isNot(contains(_OversizedResponseClient.sensitive)));
      await Future<void>.delayed(Duration.zero);
      expect(client.abortObserved, isTrue);
    });
  });
}

Future<Object> _captureError(AuthApi api) async {
  try {
    await api.issueDeviceCanvasTurnCredentials(
      bridgeId: "br_server001",
      operationId: "operation_1",
      leaseExpiresAt: 1,
      accessToken: "access-token",
    );
  } on Object catch (error) {
    return error;
  }
  throw StateError("request unexpectedly succeeded");
}

class const _SentRequest({
  required final String method,
  required final Uri url,
  required final Map<String, String>? headers,
  required final String? body,
  required final Duration deadline,
});

final class _OversizedResponseClient() extends http.BaseClient {
  static const sensitive = "credential-that-must-not-be-retained";
  bool abortObserved = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.Abortable;
    unawaited(abortable.abortTrigger?.then((_) => abortObserved = true));
    final chunk = utf8.encode(sensitive.padRight(20000, "x"));
    return http.StreamedResponse(Stream.fromIterable([chunk, chunk]), 503, request: request);
  }
}

import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_bridge/src/api/sesori_server_api.dart";
import "package:test/test.dart";

void main() {
  group("SesoriServerApi", () {
    test("sends the immediate request to the exact endpoint with a bearer token", () async {
      late http.Request request;
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test/",
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response('{"registered":true}', 200);
        }),
        requestDeadline: const Duration(seconds: 1),
      );

      final response = await api.getAppClientStatus(accessToken: "secret-token", wait: false);

      expect(response.registered, isTrue);
      expect(request.method, equals("GET"));
      expect(request.url, equals(Uri.parse("https://auth.example.test/auth/app-clients/status")));
      expect(request.headers["Authorization"], equals("Bearer secret-token"));
    });

    test("adds only wait=true for the long-poll request", () async {
      late Uri requestUri;
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((request) async {
          requestUri = request.url;
          return http.Response('{"registered":false}', 200);
        }),
        requestDeadline: const Duration(seconds: 1),
      );

      final response = await api.getAppClientStatus(accessToken: "token", wait: true);

      expect(response.registered, isFalse);
      expect(requestUri, equals(Uri.parse("https://auth.example.test/auth/app-clients/status?wait=true")));
    });

    test("rejects non-200 status and malformed response models", () async {
      final statusApi = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((_) async => http.Response("missing", 503)),
        requestDeadline: const Duration(seconds: 1),
      );
      final malformedApi = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((_) async => http.Response('{"registered":"yes"}', 200)),
        requestDeadline: const Duration(seconds: 1),
      );

      await expectLater(
        statusApi.getAppClientStatus(accessToken: "token", wait: false),
        throwsA(isA<SesoriServerApiException>().having((error) => error.statusCode, "statusCode", 503)),
      );
      await expectLater(
        malformedApi.getAppClientStatus(accessToken: "token", wait: false),
        throwsA(isA<TypeError>()),
      );
    });

    test("actively aborts a request when its deadline expires", () async {
      final client = _AbortAwareClient();
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: client,
        requestDeadline: Duration.zero,
      );

      await expectLater(
        api.getAppClientStatus(accessToken: "token", wait: false),
        throwsA(isA<http.RequestAbortedException>()),
      );
      expect(client.abortObserved, isTrue);
    });

    test("cancels the deadline after a completed response", () async {
      final client = _ImmediateClient();
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: client,
        requestDeadline: const Duration(milliseconds: 5),
      );

      await api.getAppClientStatus(accessToken: "token", wait: false);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(client.abortObserved, isFalse);
    });
  });
}

class _AbortAwareClient extends http.BaseClient {
  bool abortObserved = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.Abortable;
    await abortable.abortTrigger!;
    abortObserved = true;
    throw http.RequestAbortedException(request.url);
  }
}

class _ImmediateClient extends http.BaseClient {
  bool abortObserved = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.Abortable;
    unawaited(abortable.abortTrigger?.then((_) => abortObserved = true));
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"registered":true}')),
      200,
    );
  }
}

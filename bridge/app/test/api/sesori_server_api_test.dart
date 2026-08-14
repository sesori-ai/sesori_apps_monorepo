import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_bridge/src/api/sesori_server_api.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SesoriServerApi app-client status", () {
    test("sends immediate request to exact endpoint with bearer token", () async {
      late http.Request request;
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test/",
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response('{"registered":true}', 200);
        }),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: _FakeTokenRefresher(token: "unused"),
      );

      final response = await api.getAppClientStatus(accessToken: "secret-token");

      expect(response.registered, isTrue);
      expect(request.method, equals("GET"));
      expect(request.url, equals(Uri.parse("https://auth.example.test/auth/app-clients/status")));
      expect(request.headers["Authorization"], equals("Bearer secret-token"));
    });

    test("rejects non-200 status and malformed response models", () async {
      final statusApi = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((_) async => http.Response("missing", 503)),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: _FakeTokenRefresher(token: "unused"),
      );
      final malformedApi = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((_) async => http.Response('{"registered":"yes"}', 200)),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: _FakeTokenRefresher(token: "unused"),
      );

      await expectLater(
        statusApi.getAppClientStatus(accessToken: "token"),
        throwsA(
          isA<SesoriServerApiException>()
              .having((error) => error.method, "method", "GET")
              .having((error) => error.statusCode, "statusCode", 503),
        ),
      );
      await expectLater(malformedApi.getAppClientStatus(accessToken: "token"), throwsA(isA<TypeError>()));
    });

    test("actively aborts request when deadline expires", () async {
      final client = _AbortAwareClient();
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: client,
        requestDeadline: Duration.zero,
        tokenRefresher: _FakeTokenRefresher(token: "unused"),
      );

      await expectLater(api.getAppClientStatus(accessToken: "token"), throwsA(isA<http.RequestAbortedException>()));
      expect(client.abortObserved, isTrue);
    });

    test("cancels deadline after completed response", () async {
      final client = _ImmediateClient(responseBody: '{"registered":true}');
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: client,
        requestDeadline: const Duration(milliseconds: 5),
        tokenRefresher: _FakeTokenRefresher(token: "unused"),
      );

      await api.getAppClientStatus(accessToken: "token");
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(client.abortObserved, isFalse);
    });
  });

  group("SesoriServerApi session metadata", () {
    test("acquires token and posts typed request while decoding title-only response", () async {
      late http.Request request;
      final tokenRefresher = _FakeTokenRefresher(token: "secret-token");
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test/",
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            '{"title":"Generated title","branchName":"ignored","worktreeName":"ignored"}',
            200,
          );
        }),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: tokenRefresher,
      );

      final response = await api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "Create login flow"),
        shutdownSignal: Completer<void>().future,
      );

      expect(response.title, equals("Generated title"));
      expect(tokenRefresher.forceRefreshValues, equals([false]));
      expect(request.method, equals("POST"));
      expect(request.url, equals(Uri.parse("https://auth.example.test/sessions/generate-metadata")));
      expect(request.headers["Authorization"], equals("Bearer secret-token"));
      expect(request.headers["Content-Type"], startsWith("application/json"));
      expect(jsonDecode(request.body), equals({"firstMessage": "Create login flow"}));
    });

    test("force-refreshes once after 401 and retries with refreshed token", () async {
      final requests = <http.Request>[];
      final tokenRefresher = _FakeTokenRefresher(token: "stale", refreshedToken: "fresh");
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((request) async {
          requests.add(request);
          return request.headers["Authorization"] == "Bearer stale"
              ? http.Response("unauthorized", 401)
              : http.Response('{"title":"Retried"}', 200);
        }),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: tokenRefresher,
      );

      final response = await api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "message"),
        shutdownSignal: Completer<void>().future,
      );

      expect(response.title, equals("Retried"));
      expect(tokenRefresher.forceRefreshValues, equals([false, true]));
      expect(requests, hasLength(2));
      expect(requests.last.headers["Authorization"], equals("Bearer fresh"));
    });

    test("does not retry non-401 or second 401", () async {
      for (final statusCode in [500, 401]) {
        var requestCount = 0;
        final tokenRefresher = _FakeTokenRefresher(token: "stale", refreshedToken: "fresh");
        final api = SesoriServerApi(
          authBackendUrl: "https://auth.example.test",
          client: MockClient((_) async {
            requestCount++;
            return http.Response("failure", statusCode);
          }),
          requestDeadline: const Duration(seconds: 1),
          tokenRefresher: tokenRefresher,
        );

        await expectLater(
          api.generateSessionMetadata(
            request: const GenerateSessionMetadataRequest(firstMessage: "message"),
            shutdownSignal: Completer<void>().future,
          ),
          throwsA(
            isA<SesoriServerApiException>()
                .having((error) => error.method, "method", "POST")
                .having((error) => error.statusCode, "statusCode", statusCode),
          ),
        );
        expect(requestCount, statusCode == 401 ? 2 : 1);
        expect(tokenRefresher.forceRefreshValues, statusCode == 401 ? [false, true] : [false]);
      }
    });

    test("preserves malformed response cause", () async {
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((_) async => http.Response('{"title":1}', 200)),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: _FakeTokenRefresher(token: "token"),
      );

      await expectLater(
        api.generateSessionMetadata(
          request: const GenerateSessionMetadataRequest(firstMessage: "message"),
          shutdownSignal: Completer<void>().future,
        ),
        throwsA(
          isA<SesoriServerApiResponseException>()
              .having((error) => error.method, "method", "POST")
              .having((error) => error.innerError, "innerError", isA<TypeError>())
              .having((error) => error.innerStackTrace, "innerStackTrace", isNot(StackTrace.empty)),
        ),
      );
    });

    test("actively aborts metadata request at deadline", () async {
      final client = _AbortAwareClient();
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: client,
        requestDeadline: Duration.zero,
        tokenRefresher: _FakeTokenRefresher(token: "token"),
      );

      await expectLater(
        api.generateSessionMetadata(
          request: const GenerateSessionMetadataRequest(firstMessage: "message"),
          shutdownSignal: Completer<void>().future,
        ),
        throwsA(isA<http.RequestAbortedException>()),
      );
      expect(client.abortObserved, isTrue);
    });

    test("actively aborts metadata request on shutdown", () async {
      final client = _AbortAwareClient();
      final shutdown = Completer<void>();
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: client,
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: _FakeTokenRefresher(token: "token"),
      );

      final response = api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "message"),
        shutdownSignal: shutdown.future,
      );
      shutdown.complete();

      await expectLater(response, throwsA(isA<http.RequestAbortedException>()));
      expect(client.abortObserved, isTrue);
    });
  });
}

class _FakeTokenRefresher({required final String token, final String? refreshedToken}) implements TokenRefresher {
  final String _token = token;
  final String _refreshedToken = refreshedToken ?? token;
  final List<bool> forceRefreshValues = [];

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    forceRefreshValues.add(forceRefresh);
    return forceRefresh ? _refreshedToken : _token;
  }
}

class _AbortAwareClient() extends http.BaseClient {
  bool abortObserved = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.Abortable;
    await abortable.abortTrigger!;
    abortObserved = true;
    throw http.RequestAbortedException(request.url);
  }
}

class _ImmediateClient({required final String responseBody}) extends http.BaseClient {
  final String _responseBody = responseBody;
  bool abortObserved = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.Abortable;
    unawaited(abortable.abortTrigger?.then((_) => abortObserved = true));
    return http.StreamedResponse(Stream.value(utf8.encode(_responseBody)), 200, request: request);
  }
}

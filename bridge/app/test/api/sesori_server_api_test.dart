import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_bridge/src/api/sesori_server_api.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/foundation/abortable_request_client.dart";
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
        requestClient: const AbortableRequestClient(),
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
        requestClient: const AbortableRequestClient(),
      );
      final malformedApi = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((_) async => http.Response('{"registered":"yes"}', 200)),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: _FakeTokenRefresher(token: "unused"),
        requestClient: const AbortableRequestClient(),
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
        requestClient: const AbortableRequestClient(),
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
        requestClient: const AbortableRequestClient(),
      );

      await api.getAppClientStatus(accessToken: "token");
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(client.abortObserved, isFalse);
    });
  });

  group("SesoriServerApi session metadata", () {
    test("acquires token and posts typed request while decoding title and branch", () async {
      late http.Request request;
      final tokenRefresher = _FakeTokenRefresher(token: "secret-token");
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test/",
        client: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            '{"title":"Generated title","branchName":"generated-branch","worktreeName":"ignored"}',
            200,
          );
        }),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: tokenRefresher,
        requestClient: const AbortableRequestClient(),
      );

      final response = await api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "Create login flow"),
        abortSignal: AbortSignal(),
      );

      expect(response.title, equals("Generated title"));
      expect(response.branchName, equals("generated-branch"));
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
              : http.Response('{"title":"Retried","branchName":"retried-branch"}', 200);
        }),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: tokenRefresher,
        requestClient: const AbortableRequestClient(),
      );

      final response = await api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "message"),
        abortSignal: AbortSignal(),
      );

      expect(response.title, equals("Retried"));
      expect(response.branchName, equals("retried-branch"));
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
          requestClient: const AbortableRequestClient(),
        );

        await expectLater(
          api.generateSessionMetadata(
            request: const GenerateSessionMetadataRequest(firstMessage: "message"),
            abortSignal: AbortSignal(),
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
        requestClient: const AbortableRequestClient(),
      );

      await expectLater(
        api.generateSessionMetadata(
          request: const GenerateSessionMetadataRequest(firstMessage: "message"),
          abortSignal: AbortSignal(),
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
        requestClient: const AbortableRequestClient(),
      );

      await expectLater(
        api.generateSessionMetadata(
          request: const GenerateSessionMetadataRequest(firstMessage: "message"),
          abortSignal: AbortSignal(),
        ),
        throwsA(isA<http.RequestAbortedException>()),
      );
      expect(client.abortObserved, isTrue);
    });

    test("actively aborts metadata request on shutdown", () async {
      final client = _AbortAwareClient();
      final abortSignal = AbortSignal();
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: client,
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: _FakeTokenRefresher(token: "token"),
        requestClient: const AbortableRequestClient(),
      );

      final response = api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "message"),
        abortSignal: abortSignal,
      );
      await client.sendStarted.future;
      abortSignal.abort();

      await expectLater(response, throwsA(isA<http.RequestAbortedException>()));
      expect(client.abortObserved, isTrue);
    });

    test("aborts while acquiring the initial metadata token", () async {
      final tokenRefresher = _PendingTokenRefresher();
      final abortSignal = AbortSignal();
      var requestCount = 0;
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((_) async {
          requestCount++;
          return http.Response('{"title":"Unexpected"}', 200);
        }),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: tokenRefresher,
        requestClient: const AbortableRequestClient(),
      );

      final response = api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "message"),
        abortSignal: abortSignal,
      );
      await tokenRefresher.started.future;
      abortSignal.abort();

      await expectLater(
        response.timeout(const Duration(seconds: 1)),
        throwsA(isA<http.RequestAbortedException>()),
      );
      expect(tokenRefresher.forceRefreshValues, equals([false]));
      expect(requestCount, 0);
    });

    test("aborts while force-refreshing the metadata token after 401", () async {
      final tokenRefresher = _PendingForcedRefreshTokenRefresher();
      final abortSignal = AbortSignal();
      var requestCount = 0;
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: MockClient((_) async {
          requestCount++;
          return http.Response("unauthorized", 401);
        }),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: tokenRefresher,
        requestClient: const AbortableRequestClient(),
      );

      final response = api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "message"),
        abortSignal: abortSignal,
      );
      await tokenRefresher.forceRefreshStarted.future;
      abortSignal.abort();

      await expectLater(
        response.timeout(const Duration(seconds: 1)),
        throwsA(isA<http.RequestAbortedException>()),
      );
      expect(tokenRefresher.forceRefreshValues, equals([false, true]));
      expect(requestCount, 1);
    });

    test("releases shutdown listener after completed response", () async {
      final client = _ImmediateClient(
        responseBody: '{"title":"Generated title","branchName":"generated-branch"}',
      );
      final abortSignal = AbortSignal();
      final api = SesoriServerApi(
        authBackendUrl: "https://auth.example.test",
        client: client,
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: _FakeTokenRefresher(token: "token"),
        requestClient: const AbortableRequestClient(),
      );

      await api.generateSessionMetadata(
        request: const GenerateSessionMetadataRequest(firstMessage: "message"),
        abortSignal: abortSignal,
      );
      abortSignal.abort();
      await Future<void>.delayed(Duration.zero);

      expect(client.abortObserved, isFalse);
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

class _PendingTokenRefresher() implements TokenRefresher {
  final Completer<void> started = Completer<void>();
  final Completer<String> _token = Completer<String>();
  final List<bool> forceRefreshValues = [];

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) {
    forceRefreshValues.add(forceRefresh);
    started.complete();
    return _token.future;
  }
}

class _PendingForcedRefreshTokenRefresher() implements TokenRefresher {
  final Completer<void> forceRefreshStarted = Completer<void>();
  final Completer<String> _refreshedToken = Completer<String>();
  final List<bool> forceRefreshValues = [];

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) {
    forceRefreshValues.add(forceRefresh);
    if (!forceRefresh) return Future.value("stale");
    forceRefreshStarted.complete();
    return _refreshedToken.future;
  }
}

class _AbortAwareClient() extends http.BaseClient {
  bool abortObserved = false;
  final Completer<void> sendStarted = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.Abortable;
    sendStarted.complete();
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

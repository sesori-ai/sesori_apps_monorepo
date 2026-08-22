import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/token.dart";
import "package:sesori_bridge/src/auth/token_refresh_exception.dart";
import "package:sesori_bridge/src/auth/token_service.dart";
import "package:sesori_bridge/src/foundation/abortable_request_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("TokenService", () {
    test("Token TTL > 90s returns current token and does not call refresh", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final currentToken = _makeJwtFromNow(120);
      final manager = _tokenManager(
        initialToken: currentToken,
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "a", refreshToken: "r", lastProvider: AuthProvider.github),
        saveTokens: (_) async {},
      );

      final token = await manager.getAccessToken();

      expect(token, currentToken);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.requestCount, 0);
    });

    test("Token TTL between 30-90s returns current token and refreshes in background", () async {
      final refreshStarted = Completer<void>();
      final refreshCompleted = Completer<void>();
      final server = await _RefreshTestServer.start(
        onRequest: (_, _) {
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
        },
      );
      addTearDown(server.close);

      final currentToken = _makeJwtFromNow(60);
      // The on-disk token store is slow to load. getAccessToken must return
      // the cached token without waiting on it — the load stays gated, so any
      // await on it would time the test out instead of racing a fixed delay.
      final loadInvoked = Completer<void>();
      final loadGate = Completer<void>();
      final manager = _tokenManager(
        initialToken: currentToken,
        authBackendUrl: server.baseUrl,
        loadTokens: () async {
          if (!loadInvoked.isCompleted) {
            loadInvoked.complete();
          }
          await loadGate.future;
          return TokenData(
            accessToken: "old-access",
            refreshToken: "refresh-token",
            lastProvider: AuthProvider.github,
          );
        },
        saveTokens: (_) async {
          if (!refreshCompleted.isCompleted) {
            refreshCompleted.complete();
          }
        },
      );

      final token = await manager.getAccessToken().timeout(const Duration(seconds: 2));

      expect(token, currentToken);
      await loadInvoked.future.timeout(const Duration(seconds: 2));
      expect(loadGate.isCompleted, isFalse, reason: "getAccessToken must not wait on the slow load");

      // Release the slow load so the background refresh can finish.
      loadGate.complete();
      await refreshStarted.future.timeout(const Duration(seconds: 2));
      await refreshCompleted.future.timeout(const Duration(seconds: 2));
      expect(server.requestCount, 1);
    });

    test("Token TTL < 30s blocks and returns refreshed token", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
      );

      final token = await manager.getAccessToken();

      expect(token, "new-access-token");
      expect(server.requestCount, 1);
    });

    test("forceRefresh true always calls refresh endpoint", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(300),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
      );

      final token = await manager.getAccessToken(forceRefresh: true);

      expect(token, "new-access-token");
      expect(server.requestCount, 1);
    });

    test("3 concurrent force refresh requests perform exactly one HTTP call", () async {
      final server = await _RefreshTestServer.start(responseDelay: const Duration(milliseconds: 80));
      addTearDown(server.close);

      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(300),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
      );

      final results = await Future.wait([
        manager.getAccessToken(forceRefresh: true),
        manager.getAccessToken(forceRefresh: true),
        manager.getAccessToken(forceRefresh: true),
      ]);

      expect(results, everyElement("new-access-token"));
      expect(server.requestCount, 1);
    });

    test("successful refresh persists the rotated access/refresh pair", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      TokenData? savedTokens;
      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
      );

      await manager.getAccessToken();

      expect(savedTokens, isNotNull);
      expect(savedTokens!.accessToken, "new-access-token");
      expect(savedTokens!.refreshToken, "new-refresh-token");
      expect(savedTokens!.lastProvider, AuthProvider.github);
    });

    test("refresh repairs a corrupt token file by persisting the response tokens", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      var loadCalls = 0;
      TokenData? savedTokens;
      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async {
          loadCalls += 1;
          if (loadCalls > 1) {
            throw const FormatException("corrupt token file");
          }
          return TokenData(
            accessToken: "old-access",
            refreshToken: "refresh-token",
            lastProvider: AuthProvider.github,
          );
        },
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
      );

      final token = await manager.getAccessToken();

      expect(token, "new-access-token");
      expect(savedTokens, isNotNull);
      expect(savedTokens!.accessToken, "new-access-token");
      expect(savedTokens!.refreshToken, "new-refresh-token");
      expect(savedTokens!.lastProvider, AuthProvider.github);
    });

    test("refresh does not recreate a token file deleted mid-refresh", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      var loadCalls = 0;
      TokenData? savedTokens;
      final initialToken = _makeJwtFromNow(10);
      final manager = _tokenManager(
        initialToken: initialToken,
        authBackendUrl: server.baseUrl,
        loadTokens: () async {
          loadCalls += 1;
          if (loadCalls > 1) {
            throw const FileSystemException("token file deleted", "token.json", OSError("No such file", 2));
          }
          return TokenData(
            accessToken: "old-access",
            refreshToken: "refresh-token",
            lastProvider: AuthProvider.github,
          );
        },
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
      );

      await expectLater(manager.getAccessToken(), throwsA(isA<FileSystemException>()));
      expect(savedTokens, isNull);
      // The refreshed token must not leak onto the in-memory stream when the
      // file was cleared mid-refresh — a reconnect must not be able to use it.
      expect(manager.accessToken, initialToken);
    });

    test("refresh that finds the token file cleared (null) does not publish the new token", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      var loadCalls = 0;
      TokenData? savedTokens;
      final initialToken = _makeJwtFromNow(10);
      final manager = _tokenManager(
        initialToken: initialToken,
        authBackendUrl: server.baseUrl,
        loadTokens: () async {
          loadCalls += 1;
          if (loadCalls > 1) {
            return null;
          }
          return TokenData(
            accessToken: "old-access",
            refreshToken: "refresh-token",
            lastProvider: AuthProvider.github,
          );
        },
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
      );

      await expectLater(manager.getAccessToken(), throwsA(isA<TokenRefreshException>()));
      expect(savedTokens, isNull);
      expect(manager.accessToken, initialToken);
    });

    test("successful refresh updates current access token", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
      );

      await manager.getAccessToken();

      expect(manager.accessToken, "new-access-token");
    });

    test("non-200 refresh response throws", () async {
      final server = await _RefreshTestServer.start(statusCode: 401);
      addTearDown(server.close);

      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
      );

      expect(manager.getAccessToken(), throwsA(isA<TokenRefreshException>()));
    });

    test("network error during refresh throws", () async {
      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: "http://127.0.0.1:1",
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
        client: _ThrowingClient(),
      );

      expect(manager.getAccessToken(), throwsA(isA<Exception>()));
    });

    test("request deadline settles a stalled refresh", () async {
      final client = _AbortAwareClient();
      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: "https://auth.example.test",
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
        client: client,
        requestDeadline: const Duration(milliseconds: 10),
      );

      await expectLater(
        manager.getAccessToken().timeout(const Duration(seconds: 1)),
        throwsA(isA<http.RequestAbortedException>()),
      );
    });

    test("request deadline actively aborts the refresh request", () async {
      final client = _AbortAwareClient();
      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: "https://auth.example.test",
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
        client: client,
        requestDeadline: Duration.zero,
      );

      await expectLater(manager.getAccessToken(), throwsA(isA<http.RequestAbortedException>()));
      expect(client.abortObserved, isTrue);
    });

    test("background refresh deadline has no unhandled losing future", () async {
      final unhandledErrors = <Object>[];
      await runZonedGuarded(
        () async {
          final client = _AbortAwareClient();
          final currentToken = _makeJwtFromNow(60);
          final manager = _tokenManager(
            initialToken: currentToken,
            authBackendUrl: "https://auth.example.test",
            loadTokens: () async => TokenData(
              accessToken: "old-access",
              refreshToken: "refresh-token",
              lastProvider: AuthProvider.github,
            ),
            saveTokens: (_) async {},
            client: client,
            requestDeadline: Duration.zero,
          );

          expect(await manager.getAccessToken(), currentToken);
          await client.abortObservedFuture.timeout(const Duration(seconds: 1));
          await Future<void>.delayed(Duration.zero);
        },
        (error, _) => unhandledErrors.add(error),
      );

      expect(unhandledErrors, isEmpty);
    });

    test("missing tokens from loader throws", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => null,
        saveTokens: (_) async {},
      );

      expect(manager.getAccessToken(), throwsA(isA<TokenRefreshException>()));
    });

    test("empty refresh token throws", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = _tokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async =>
            TokenData(accessToken: "old-access", refreshToken: "", lastProvider: AuthProvider.github),
        saveTokens: (_) async {},
      );

      expect(manager.getAccessToken(), throwsA(isA<TokenRefreshException>()));
    });

    test("malformed JWT returns current token without proactive refresh", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      const malformedJwt = "not-a-jwt";
      final manager = _tokenManager(
        initialToken: malformedJwt,
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          lastProvider: AuthProvider.github,
        ),
        saveTokens: (_) async {},
      );

      final token = await manager.getAccessToken();

      expect(token, malformedJwt);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.requestCount, 0);
    });
  });
}

class _ThrowingClient() extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw Exception("network error");
  }
}

class _AbortAwareClient() extends http.BaseClient {
  final Completer<void> _abortObserved = Completer<void>();

  bool get abortObserved => _abortObserved.isCompleted;
  Future<void> get abortObservedFuture => _abortObserved.future;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.Abortable;
    await abortable.abortTrigger!;
    _abortObserved.complete();
    throw http.RequestAbortedException(request.url);
  }
}

TokenService _tokenManager({
  required String initialToken,
  required String authBackendUrl,
  required Future<TokenData?> Function() loadTokens,
  required Future<void> Function(TokenData) saveTokens,
  http.Client? client,
  Duration requestDeadline = const Duration(seconds: 1),
}) {
  final manager = TokenService(
    initialToken: initialToken,
    authBackendUrl: authBackendUrl,
    loadTokens: loadTokens,
    saveTokens: saveTokens,
    ownedClient: client ?? http.Client(),
    requestDeadline: requestDeadline,
    requestClient: const AbortableRequestClient(),
  );
  addTearDown(manager.dispose);
  return manager;
}

class _RefreshTestServer._(
  final HttpServer _server,
  final int _statusCode,
  final Duration _responseDelay,
  final void Function(HttpRequest request, String body)? _onRequest,
) {
  int requestCount = 0;

  static Future<_RefreshTestServer> start({
    int statusCode = 200,
    Duration responseDelay = Duration.zero,
    void Function(HttpRequest request, String body)? onRequest,
  }) async {
    final server = await HttpServer.bind("127.0.0.1", 0);
    final testServer = _RefreshTestServer._(server, statusCode, responseDelay, onRequest);
    server.listen(testServer._handle);
    return testServer;
  }

  String get baseUrl => "http://${_server.address.host}:${_server.port}";

  Future<void> close() async {
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    requestCount += 1;

    final body = await utf8.decoder.bind(request).join();
    _onRequest?.call(request, body);

    if (_responseDelay > Duration.zero) {
      await Future<void>.delayed(_responseDelay);
    }

    if (_statusCode == 200) {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          "accessToken": "new-access-token",
          "refreshToken": "new-refresh-token",
          "user": {
            "id": "user-1",
            "provider": "github",
            "providerUserId": "provider-user-1",
          },
        }),
      );
    } else {
      request.response.statusCode = _statusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({"error": "refresh failed"}));
    }

    await request.response.close();
  }
}

String _makeJwtFromNow(int ttlSeconds) {
  final now = DateTime.now().toUtc();
  final exp = now.add(Duration(seconds: ttlSeconds)).millisecondsSinceEpoch ~/ 1000;
  return _makeJwt(exp);
}

String _makeJwt(int expSeconds) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({"exp": expSeconds}))).replaceAll("=", "");
  return "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.$payload.signature";
}

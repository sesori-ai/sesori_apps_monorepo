import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/token.dart";
import "package:sesori_bridge/src/auth/token_manager.dart";
import "package:sesori_bridge/src/auth/token_refresh_exception.dart";
import "package:test/test.dart";

void main() {
  group("TokenManager", () {
    test("Token TTL > 90s returns current token and does not call refresh", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final currentToken = _makeJwtFromNow(120);
      final manager = TokenManager(
        initialToken: currentToken,
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "a", refreshToken: "r"),
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
        onRequest: (_, __) {
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
        },
      );
      addTearDown(server.close);

      final currentToken = _makeJwtFromNow(60);
      final manager = TokenManager(
        initialToken: currentToken,
        authBackendUrl: server.baseUrl,
        loadTokens: () async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          return TokenData(accessToken: "old-access", refreshToken: "refresh-token");
        },
        saveTokens: (_) async {
          if (!refreshCompleted.isCompleted) {
            refreshCompleted.complete();
          }
        },
      );

      final start = DateTime.now();
      final token = await manager.getAccessToken();
      final elapsed = DateTime.now().difference(start);

      expect(token, currentToken);
      expect(elapsed, lessThan(const Duration(milliseconds: 120)));

      await refreshStarted.future.timeout(const Duration(seconds: 2));
      await refreshCompleted.future.timeout(const Duration(seconds: 2));
      expect(server.requestCount, 1);
    });

    test("Token TTL < 30s blocks and returns refreshed token", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = TokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "old-access", refreshToken: "refresh-token"),
        saveTokens: (_) async {},
      );

      final token = await manager.getAccessToken();

      expect(token, "new-access-token");
      expect(server.requestCount, 1);
    });

    test("forceRefresh true always calls refresh endpoint", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = TokenManager(
        initialToken: _makeJwtFromNow(300),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "old-access", refreshToken: "refresh-token"),
        saveTokens: (_) async {},
      );

      final token = await manager.getAccessToken(forceRefresh: true);

      expect(token, "new-access-token");
      expect(server.requestCount, 1);
    });

    test("3 concurrent force refresh requests perform exactly one HTTP call", () async {
      final server = await _RefreshTestServer.start(responseDelay: const Duration(milliseconds: 80));
      addTearDown(server.close);

      final manager = TokenManager(
        initialToken: _makeJwtFromNow(300),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "old-access", refreshToken: "refresh-token"),
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

    test("successful refresh persists new tokens while preserving bridgeToken", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      TokenData? savedTokens;
      final manager = TokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(
          accessToken: "old-access",
          refreshToken: "refresh-token",
          bridgeToken: "bridge-token-value",
        ),
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
      );

      await manager.getAccessToken();

      expect(savedTokens, isNotNull);
      expect(savedTokens!.accessToken, "new-access-token");
      expect(savedTokens!.refreshToken, "new-refresh-token");
      expect(savedTokens!.bridgeToken, "bridge-token-value");
    });

    test("successful refresh updates current access token", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = TokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "old-access", refreshToken: "refresh-token"),
        saveTokens: (_) async {},
      );

      await manager.getAccessToken();

      expect(manager.accessToken, "new-access-token");
    });

    test("non-200 refresh response throws", () async {
      final server = await _RefreshTestServer.start(statusCode: 401);
      addTearDown(server.close);

      final manager = TokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "old-access", refreshToken: "refresh-token"),
        saveTokens: (_) async {},
      );

      expect(manager.getAccessToken(), throwsA(isA<TokenRefreshException>()));
    });

    test("network error during refresh throws", () async {
      final manager = TokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: "http://127.0.0.1:1",
        loadTokens: () async => TokenData(accessToken: "old-access", refreshToken: "refresh-token"),
        saveTokens: (_) async {},
        client: _ThrowingClient(),
      );

      expect(manager.getAccessToken(), throwsA(isA<Exception>()));
    });

    test("missing tokens from loader throws", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      final manager = TokenManager(
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

      final manager = TokenManager(
        initialToken: _makeJwtFromNow(10),
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "old-access", refreshToken: ""),
        saveTokens: (_) async {},
      );

      expect(manager.getAccessToken(), throwsA(isA<TokenRefreshException>()));
    });

    test("malformed JWT returns current token without proactive refresh", () async {
      final server = await _RefreshTestServer.start();
      addTearDown(server.close);

      const malformedJwt = "not-a-jwt";
      final manager = TokenManager(
        initialToken: malformedJwt,
        authBackendUrl: server.baseUrl,
        loadTokens: () async => TokenData(accessToken: "old-access", refreshToken: "refresh-token"),
        saveTokens: (_) async {},
      );

      final token = await manager.getAccessToken();

      expect(token, malformedJwt);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(server.requestCount, 0);
    });
  });
}

class _ThrowingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw Exception("network error");
  }
}

class _RefreshTestServer {
  final HttpServer _server;
  final int _statusCode;
  final Duration _responseDelay;
  final void Function(HttpRequest request, String body)? _onRequest;

  int requestCount = 0;

  _RefreshTestServer._(
    this._server,
    this._statusCode,
    this._responseDelay,
    this._onRequest,
  );

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

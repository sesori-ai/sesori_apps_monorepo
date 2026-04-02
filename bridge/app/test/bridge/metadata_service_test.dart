import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/metadata_service.dart";
import "package:sesori_bridge/src/bridge/models/session_metadata.dart";
import "package:test/test.dart";

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeTokenRefresher implements TokenRefresher {
  final String _token;
  final String _forceRefreshedToken;
  int forceRefreshCallCount = 0;

  _FakeTokenRefresher({
    required String token,
    String? forceRefreshedToken,
  }) : _token = token,
       _forceRefreshedToken = forceRefreshedToken ?? token;

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      forceRefreshCallCount++;
      return _forceRefreshedToken;
    }
    return _token;
  }
}

class _SocketErrorClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw const SocketException("Connection refused");
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

MetadataService _makeService({
  required HttpServer server,
  required _FakeTokenRefresher tokenRefresher,
}) => MetadataService(
  client: http.Client(),
  baseUrl: "http://127.0.0.1:${server.port}",
  tokenRefresher: tokenRefresher,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group("MetadataService", () {
    test("200 success → returns SessionMetadata with correct fields", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(() => server.close(force: true));

      unawaited(
        server.listen((request) async {
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({"title": "My Session", "branchName": "feat/my-session"}),
          );
          await request.response.close();
        }).asFuture<void>(),
      );

      final service = _makeService(
        server: server,
        tokenRefresher: _FakeTokenRefresher(token: "my-token"),
      );

      final result = await service.generate(firstMessage: "Hello world");

      expect(result, isA<SessionMetadata>());
      expect(result!.title, equals("My Session"));
      expect(result.branchName, equals("feat/my-session"));
    });

    test("non-200 status → returns null", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(() => server.close(force: true));

      unawaited(
        server.listen((request) async {
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }).asFuture<void>(),
      );

      final service = _makeService(
        server: server,
        tokenRefresher: _FakeTokenRefresher(token: "my-token"),
      );

      final result = await service.generate(firstMessage: "Hello world");

      expect(result, isNull);
    });

    test("SocketException → returns null", () async {
      final service = MetadataService(
        client: _SocketErrorClient(),
        baseUrl: "http://127.0.0.1:1",
        tokenRefresher: _FakeTokenRefresher(token: "my-token"),
      );

      final result = await service.generate(firstMessage: "Hello world");

      expect(result, isNull);
    });

    test("malformed JSON → returns null", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(() => server.close(force: true));

      unawaited(
        server.listen((request) async {
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
          request.response.write("not {{ valid json");
          await request.response.close();
        }).asFuture<void>(),
      );

      final service = _makeService(
        server: server,
        tokenRefresher: _FakeTokenRefresher(token: "my-token"),
      );

      final result = await service.generate(firstMessage: "Hello world");

      expect(result, isNull);
    });

    test("401 → token refresh → retry → success", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(() => server.close(force: true));

      var requestCount = 0;
      final receivedTokens = <String>[];

      unawaited(
        server.listen((request) async {
          requestCount++;
          receivedTokens.add(
            request.headers.value(HttpHeaders.authorizationHeader) ?? "",
          );
          await utf8.decoder.bind(request).join();
          if (requestCount == 1) {
            request.response.statusCode = HttpStatus.unauthorized;
          } else {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({"title": "Retried", "branchName": "feat/retried"}),
            );
          }
          await request.response.close();
        }).asFuture<void>(),
      );

      final tokenRefresher = _FakeTokenRefresher(
        token: "initial-token",
        forceRefreshedToken: "refreshed-token",
      );
      final service = _makeService(
        server: server,
        tokenRefresher: tokenRefresher,
      );

      final result = await service.generate(firstMessage: "Hello world");

      expect(result, isA<SessionMetadata>());
      expect(result!.title, equals("Retried"));
      expect(result.branchName, equals("feat/retried"));
      expect(requestCount, equals(2));
      expect(tokenRefresher.forceRefreshCallCount, equals(1));
      expect(receivedTokens[0], equals("Bearer initial-token"));
      expect(receivedTokens[1], equals("Bearer refreshed-token"));
    });

    test("401 → token refresh → retry → still 401 → returns null", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(() => server.close(force: true));

      var requestCount = 0;

      unawaited(
        server.listen((request) async {
          requestCount++;
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
        }).asFuture<void>(),
      );

      final tokenRefresher = _FakeTokenRefresher(
        token: "initial-token",
        forceRefreshedToken: "refreshed-token",
      );
      final service = _makeService(
        server: server,
        tokenRefresher: tokenRefresher,
      );

      final result = await service.generate(firstMessage: "Hello world");

      expect(result, isNull);
      expect(requestCount, equals(2));
      expect(tokenRefresher.forceRefreshCallCount, equals(1));
    });

    test("Bearer token sent in Authorization header", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(() => server.close(force: true));

      final receivedAuth = Completer<String?>();

      unawaited(
        server.listen((request) async {
          receivedAuth.complete(
            request.headers.value(HttpHeaders.authorizationHeader),
          );
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({"title": "T", "branchName": "b"}));
          await request.response.close();
        }).asFuture<void>(),
      );

      final service = _makeService(
        server: server,
        tokenRefresher: _FakeTokenRefresher(token: "secret-token"),
      );

      await service.generate(firstMessage: "Hello");

      final auth = await receivedAuth.future.timeout(const Duration(seconds: 2));
      expect(auth, equals("Bearer secret-token"));
    });

    test("firstMessage truncated to 500 chars", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(() => server.close(force: true));

      final receivedBody = Completer<Map<String, dynamic>>();

      unawaited(
        server.listen((request) async {
          final body = await utf8.decoder.bind(request).join();
          receivedBody.complete(jsonDecode(body) as Map<String, dynamic>);
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({"title": "T", "branchName": "b"}));
          await request.response.close();
        }).asFuture<void>(),
      );

      final service = _makeService(
        server: server,
        tokenRefresher: _FakeTokenRefresher(token: "my-token"),
      );

      final longMessage = "x" * 600;
      await service.generate(firstMessage: longMessage);

      final body = await receivedBody.future.timeout(const Duration(seconds: 2));
      final sentMessage = body["firstMessage"] as String;
      expect(sentMessage.length, equals(500));
      expect(sentMessage, equals("x" * 500));
    });
  });
}

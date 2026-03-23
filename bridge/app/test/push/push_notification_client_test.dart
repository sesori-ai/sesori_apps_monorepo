import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _FakeTokenRefreshManager implements TokenRefresher {
  final String _token;
  final String? _forceRefreshToken;
  bool forceRefreshCalled = false;

  _FakeTokenRefreshManager(this._token, {String? forceRefreshToken}) : _forceRefreshToken = forceRefreshToken;

  @override
  Future<String> getFreshAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      forceRefreshCalled = true;
      if (_forceRefreshToken != null) return _forceRefreshToken;
      throw Exception("Force refresh failed");
    }
    return _token;
  }
}

void main() {
  group("PushNotificationClient", () {
    test("sends POST request with auth header and payload", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(server.close);

      final received = Completer<({Map<String, dynamic> body, String? authorization, String path})>();

      unawaited(
        server.listen((request) async {
          final body = await utf8.decoder.bind(request).join();
          received.complete((
            body: jsonDecode(body) as Map<String, dynamic>,
            authorization: request.headers.value(HttpHeaders.authorizationHeader),
            path: request.uri.path,
          ));
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
        }).asFuture<void>(),
      );

      final fakeManager = _FakeTokenRefreshManager("token-123");
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:${server.port}",
        tokenRefreshManager: fakeManager,
      );

      await client.sendNotification(
        const SendNotificationPayload(
          category: NotificationCategory.aiInteraction,
          title: "Action required",
          body: "Approve this command",
          collapseKey: "ai_interaction-session-a",
          data: NotificationData(
            category: NotificationCategory.aiInteraction,
            eventType: NotificationEventType.questionAsked,
            sessionId: "session-a",
          ),
        ),
      );

      final request = await received.future.timeout(const Duration(seconds: 2));
      expect(request.path, equals("/notifications/send"));
      expect(request.authorization, equals("Bearer token-123"));
      expect(request.body, {
        "category": "ai_interaction",
        "title": "Action required",
        "body": "Approve this command",
        "collapseKey": "ai_interaction-session-a",
        "data": {
          "category": "ai_interaction",
          "eventType": "question_asked",
          "sessionId": "session-a",
        },
      });
    });

    test("network error → throws", () async {
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:1",
        tokenRefreshManager: _FakeTokenRefreshManager("token-123"),
      );

      await expectLater(
        client.sendNotification(
          const SendNotificationPayload(
            category: NotificationCategory.aiInteraction,
            title: "Action required",
            body: "Approve this command",
            collapseKey: "ai_interaction-global",
            data: NotificationData(
              category: NotificationCategory.aiInteraction,
              eventType: NotificationEventType.questionAsked,
              sessionId: null,
            ),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test("200 OK → success, no retry", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(server.close);

      var requestCount = 0;
      unawaited(
        server.listen((request) async {
          requestCount++;
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
        }).asFuture<void>(),
      );

      final fakeManager = _FakeTokenRefreshManager("token-abc");
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:${server.port}",
        tokenRefreshManager: fakeManager,
      );

      await client.sendNotification(
        const SendNotificationPayload(
          category: NotificationCategory.aiInteraction,
          title: "Test",
          body: "Body",
          collapseKey: "key",
          data: NotificationData(
            category: NotificationCategory.aiInteraction,
            eventType: NotificationEventType.questionAsked,
            sessionId: null,
          ),
        ),
      );

      expect(requestCount, equals(1));
      expect(fakeManager.forceRefreshCalled, isFalse);
    });

    test("401 → force refresh → retry → 200 → success", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(server.close);

      var requestCount = 0;
      final receivedTokens = <String>[];

      unawaited(
        server.listen((request) async {
          requestCount++;
          final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? "";
          receivedTokens.add(auth);
          await utf8.decoder.bind(request).join();
          // First request → 401, second → 200
          request.response.statusCode = requestCount == 1 ? HttpStatus.unauthorized : HttpStatus.ok;
          await request.response.close();
        }).asFuture<void>(),
      );

      final fakeManager = _FakeTokenRefreshManager(
        "old-token",
        forceRefreshToken: "new-token",
      );
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:${server.port}",
        tokenRefreshManager: fakeManager,
      );

      await client.sendNotification(
        const SendNotificationPayload(
          category: NotificationCategory.aiInteraction,
          title: "Test",
          body: "Body",
          collapseKey: "key",
          data: NotificationData(
            category: NotificationCategory.aiInteraction,
            eventType: NotificationEventType.questionAsked,
            sessionId: null,
          ),
        ),
      );

      expect(requestCount, equals(2));
      expect(fakeManager.forceRefreshCalled, isTrue);
      expect(receivedTokens[0], equals("Bearer old-token"));
      expect(receivedTokens[1], equals("Bearer new-token"));
    });

    test("401 → refresh → retry → 401 again → throws", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(server.close);

      var requestCount = 0;
      unawaited(
        server.listen((request) async {
          requestCount++;
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
        }).asFuture<void>(),
      );

      final fakeManager = _FakeTokenRefreshManager(
        "old-token",
        forceRefreshToken: "new-token",
      );
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:${server.port}",
        tokenRefreshManager: fakeManager,
      );

      await expectLater(
        client.sendNotification(
          const SendNotificationPayload(
            category: NotificationCategory.aiInteraction,
            title: "Test",
            body: "Body",
            collapseKey: "key",
            data: NotificationData(
              category: NotificationCategory.aiInteraction,
              eventType: NotificationEventType.questionAsked,
              sessionId: null,
            ),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(requestCount, equals(2));
    });

    test("401 → refresh fails → throws", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(server.close);

      unawaited(
        server.listen((request) async {
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
        }).asFuture<void>(),
      );

      // No forceRefreshToken → will throw on force refresh
      final fakeManager = _FakeTokenRefreshManager("old-token");
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:${server.port}",
        tokenRefreshManager: fakeManager,
      );

      await expectLater(
        client.sendNotification(
          const SendNotificationPayload(
            category: NotificationCategory.aiInteraction,
            title: "Test",
            body: "Body",
            collapseKey: "key",
            data: NotificationData(
              category: NotificationCategory.aiInteraction,
              eventType: NotificationEventType.questionAsked,
              sessionId: null,
            ),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(fakeManager.forceRefreshCalled, isTrue);
    });

    test("500 → throws immediately", () async {
      final server = await HttpServer.bind("127.0.0.1", 0);
      addTearDown(server.close);

      var requestCount = 0;
      unawaited(
        server.listen((request) async {
          requestCount++;
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }).asFuture<void>(),
      );

      final fakeManager = _FakeTokenRefreshManager("token-xyz");
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:${server.port}",
        tokenRefreshManager: fakeManager,
      );

      await expectLater(
        client.sendNotification(
          const SendNotificationPayload(
            category: NotificationCategory.aiInteraction,
            title: "Test",
            body: "Body",
            collapseKey: "key",
            data: NotificationData(
              category: NotificationCategory.aiInteraction,
              eventType: NotificationEventType.questionAsked,
              sessionId: null,
            ),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(requestCount, equals(1));
      expect(fakeManager.forceRefreshCalled, isFalse);
    });
  });
}

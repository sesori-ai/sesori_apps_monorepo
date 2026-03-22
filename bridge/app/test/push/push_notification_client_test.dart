import "dart:async";
import "dart:convert";
import "dart:io";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/auth/access_token_provider.dart";
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _FakeAccessTokenProvider implements AccessTokenProvider {
  final BehaviorSubject<String> _subject;

  _FakeAccessTokenProvider(String token) : _subject = BehaviorSubject.seeded(token);

  @override
  String get accessToken => _subject.value;

  @override
  ValueStream<String> get tokenStream => _subject.stream;
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

      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:${server.port}",
        accessTokenProvider: _FakeAccessTokenProvider("token-123"),
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

    test("swallows transport errors", () async {
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:1",
        accessTokenProvider: _FakeAccessTokenProvider("token-123"),
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
        completes,
      );
    });
  });
}

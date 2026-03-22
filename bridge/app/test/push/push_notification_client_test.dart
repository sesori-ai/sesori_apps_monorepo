import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:test/test.dart";

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
        accessTokenProvider: () => "token-123",
      );

      await client.sendNotification(
        category: "ai_interaction",
        title: "Action required",
        body: "Approve this command",
        collapseKey: "ai_interaction-session-a",
        data: const {"sessionId": "session-a"},
      );

      final request = await received.future.timeout(const Duration(seconds: 2));
      expect(request.path, equals("/notifications/send"));
      expect(request.authorization, equals("Bearer token-123"));
      expect(request.body, {
        "category": "ai_interaction",
        "title": "Action required",
        "body": "Approve this command",
        "collapseKey": "ai_interaction-session-a",
        "data": {"sessionId": "session-a"},
      });
    });

    test("swallows transport errors", () async {
      final client = PushNotificationClient(
        authBackendURL: "http://127.0.0.1:1",
        accessTokenProvider: () => "token-123",
      );

      await expectLater(
        client.sendNotification(
          category: "ai_interaction",
          title: "Action required",
          body: "Approve this command",
        ),
        completes,
      );
    });
  });
}

import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:flutter_web_auth_2/flutter_web_auth_2.dart";
import "package:integration_test/integration_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("native authentication returns nonce-only loopback bounce", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    final callbackServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final authorizationServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    const nonce = "synthetic-nonce";
    const callbackScheme = "com.sesori.auth";
    final callbackUri = Uri.parse("http://127.0.0.1:${callbackServer.port}/callback");
    final authorizeUri = Uri.parse("http://127.0.0.1:${authorizationServer.port}/authorize");
    final callbackCompleter = Completer<Uri>();

    final authorizationSubscription = authorizationServer.listen((request) async {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(
          HttpHeaders.locationHeader,
          callbackUri
              .replace(
                queryParameters: const {
                  "state": "synthetic-state",
                  "code": "synthetic-code",
                },
              )
              .toString(),
        );
      await request.response.close();
    });
    final callbackSubscription = callbackServer.listen((request) async {
      callbackCompleter.complete(
        callbackUri.replace(queryParameters: request.uri.queryParameters),
      );
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, "$callbackScheme://complete/$nonce");
      await request.response.close();
    });

    try {
      final returned = Uri.parse(
        await FlutterWebAuth2.authenticate(
          url: authorizeUri.toString(),
          callbackUrlScheme: callbackScheme,
        ),
      );
      final captured = await callbackCompleter.future.timeout(const Duration(seconds: 5));

      expect(returned, Uri.parse("$callbackScheme://complete/$nonce"));
      expect(returned.queryParameters, isEmpty);
      expect(captured.queryParameters, const {
        "state": "synthetic-state",
        "code": "synthetic-code",
      });
    } finally {
      await authorizationSubscription.cancel();
      await callbackSubscription.cancel();
      await authorizationServer.close(force: true);
      await callbackServer.close(force: true);
    }
  });
}

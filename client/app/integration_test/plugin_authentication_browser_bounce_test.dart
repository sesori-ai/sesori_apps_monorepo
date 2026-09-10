import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_plugin_authentication_browser.dart";
import "package:sesori_mobile/core/platform/flutter_web_auth_client.dart";

class _RecordingAuthenticationBrowser({required final PluginAuthenticationBrowser delegate})
    implements PluginAuthenticationBrowser {
  final PluginAuthenticationBrowser _delegate = delegate;
  PluginAuthenticationBrowserResult? result;

  @override
  bool get returnsToApp => _delegate.returnsToApp;

  @override
  Future<PluginAuthenticationBrowserResult> open({
    required Uri authorizationUri,
    required String callbackScheme,
  }) async {
    final value = await _delegate.open(authorizationUri: authorizationUri, callbackScheme: callbackScheme);
    result = value;
    return value;
  }
}

Future<int> _unusedLoopbackPort() async {
  final reservation = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = reservation.port;
  await reservation.close();
  return port;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("production browser service returns nonce-only native bounce and captures loopback payload", (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    final callbackPort = await _unusedLoopbackPort();
    final callbackUri = Uri.parse("http://127.0.0.1:$callbackPort/callback");
    final authorizationServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final authorizeUri = Uri.parse("http://127.0.0.1:${authorizationServer.port}/authorize");
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
    final browser = _RecordingAuthenticationBrowser(
      delegate: FlutterPluginAuthenticationBrowser(client: FlutterWebAuthClient()),
    );
    final browserService = PluginAuthenticationBrowserService(
      loopbackServer: PluginAuthenticationLoopbackServer(),
      browser: browser,
    );
    final phases = <PluginAuthenticationBrowserPhase>[];
    final detachedFailures = <PluginAuthenticationBrowserFlowFailed>[];

    try {
      final result = await browserService.authenticate(
        challenge: PluginAuthenticationBrowserChallenge(
          authorizationUri: authorizeUri,
          expectedCallbackUri: callbackUri,
        ),
        isLocalBridge: false,
        reuseActiveListener: false,
        onPhase: phases.add,
        onDetachedFailure: detachedFailures.add,
      );

      expect(result, isA<PluginAuthenticationBrowserCaptured>());
      if (result case PluginAuthenticationBrowserCaptured(:final callbackUri)) {
        expect(callbackUri.queryParameters, const {
          "state": "synthetic-state",
          "code": "synthetic-code",
        });
      }
      expect(phases, [PluginAuthenticationBrowserPhase.opening, PluginAuthenticationBrowserPhase.waiting]);
      expect(detachedFailures, isEmpty);

      final nativeResult = browser.result;
      expect(nativeResult, isA<PluginAuthenticationBrowserReturned>());
      if (nativeResult case PluginAuthenticationBrowserReturned(:final callbackUri)) {
        expect(callbackUri.scheme, pluginAuthenticationCallbackScheme);
        expect(callbackUri.host, "complete");
        expect(callbackUri.pathSegments, hasLength(1));
        expect(callbackUri.pathSegments.single, isNotEmpty);
        expect(callbackUri.query, isEmpty);
        expect(callbackUri.fragment, isEmpty);
      }
    } finally {
      await browserService.cancelActive();
      await authorizationSubscription.cancel();
      await authorizationServer.close(force: true);
    }
  });
}

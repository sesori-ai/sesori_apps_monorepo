import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_plugin_authentication_browser.dart";
import "package:sesori_mobile/core/platform/flutter_web_auth_client.dart";

class _MockFlutterWebAuthClient() extends Mock implements FlutterWebAuthClient;

void main() {
  late _MockFlutterWebAuthClient client;
  late FlutterPluginAuthenticationBrowser browser;

  setUp(() {
    client = _MockFlutterWebAuthClient();
    browser = FlutterPluginAuthenticationBrowser(client: client);
  });

  test("returns only parsed native callback", () async {
    when(
      () => client.authenticate(
        url: any(named: "url"),
        callbackUrlScheme: any(named: "callbackUrlScheme"),
      ),
    ).thenAnswer((_) async => "com.sesori.auth://complete/nonce");

    final result = await browser.open(
      authorizationUri: Uri.parse("https://provider.example/authorize"),
      callbackScheme: "com.sesori.auth",
    );
    expect(
      result,
      isA<PluginAuthenticationBrowserReturned>().having(
        (result) => result.callbackUri,
        "callbackUri",
        Uri.parse("com.sesori.auth://complete/nonce"),
      ),
    );
  });

  test("maps an invalid native return to a closed safe reason", () async {
    when(
      () => client.authenticate(
        url: any(named: "url"),
        callbackUrlScheme: any(named: "callbackUrlScheme"),
      ),
    ).thenAnswer((_) async => "http://[");

    expect(
      await browser.open(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        callbackScheme: "com.sesori.auth",
      ),
      isA<PluginAuthenticationBrowserFailed>().having(
        (result) => result.innerError,
        "safe reason",
        PluginAuthenticationBrowserFailureReason.invalidNativeReturn,
      ),
    );
  });

  test("maps native cancel distinctly from launch failure", () async {
    when(
      () => client.authenticate(
        url: any(named: "url"),
        callbackUrlScheme: any(named: "callbackUrlScheme"),
      ),
    ).thenThrow(PlatformException(code: "CANCELED"));

    expect(
      await browser.open(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        callbackScheme: "com.sesori.auth",
      ),
      isA<PluginAuthenticationBrowserCancelled>(),
    );

    final failure = PlatformException(
      code: "FAILED_TO_START",
      message: "https://provider.example/authorize?state=private-state",
      details: "code=private-code",
    );
    when(
      () => client.authenticate(
        url: any(named: "url"),
        callbackUrlScheme: any(named: "callbackUrlScheme"),
      ),
    ).thenThrow(failure);
    expect(
      await browser.open(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        callbackScheme: "com.sesori.auth",
      ),
      isA<PluginAuthenticationBrowserFailed>().having(
        (result) => result.innerError,
        "typed platform cause",
        isA<PluginAuthenticationBrowserPlatformException>()
            .having((error) => error.innerError, "original error", same(failure))
            .having((error) => error.toString(), "safe diagnostic", "Native authentication failed (FAILED_TO_START)"),
      ),
    );
  });
}

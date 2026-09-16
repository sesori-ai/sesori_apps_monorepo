import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_plugin_authentication_browser.dart";

class _MockUrlLauncher() extends Mock implements UrlLauncher;

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse("https://example.com"));
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

  test("opens external browser without claiming authentication success", () async {
    final launcher = _MockUrlLauncher();
    when(() => launcher.launch(any(), mode: any(named: "mode"))).thenAnswer((_) async => true);
    final browser = DesktopPluginAuthenticationBrowser(urlLauncher: launcher);

    expect(
      await browser.open(
        authorizationUri: Uri.parse("https://provider.example/authorize"),
        callbackScheme: "com.sesori.auth",
      ),
      isA<PluginAuthenticationBrowserOpened>(),
    );
    expect(browser.returnsToApp, isFalse);
  });
}

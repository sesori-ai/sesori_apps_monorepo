import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: PluginAuthenticationBrowser)
class DesktopPluginAuthenticationBrowser({required UrlLauncher urlLauncher}) implements PluginAuthenticationBrowser {
  final UrlLauncher _urlLauncher = urlLauncher;

  @override
  bool get returnsToApp => false;

  @override
  Future<PluginAuthenticationBrowserResult> open({
    required Uri authorizationUri,
    required String callbackScheme,
  }) async {
    final opened = await _urlLauncher.launch(authorizationUri);
    return opened
        ? const PluginAuthenticationBrowserOpened()
        : PluginAuthenticationBrowserFailed(
            innerError: StateError("No system browser accepted the authentication request"),
            stackTrace: StackTrace.current,
          );
  }
}

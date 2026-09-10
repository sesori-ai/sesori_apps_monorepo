import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "flutter_web_auth_client.dart";

@LazySingleton(as: PluginAuthenticationBrowser)
class FlutterPluginAuthenticationBrowser({required FlutterWebAuthClient client})
    implements PluginAuthenticationBrowser {
  final FlutterWebAuthClient _client = client;

  @override
  bool get returnsToApp => true;

  @override
  Future<PluginAuthenticationBrowserResult> open({
    required Uri authorizationUri,
    required String callbackScheme,
  }) async {
    try {
      final callback = await _client.authenticate(
        url: authorizationUri.toString(),
        callbackUrlScheme: callbackScheme,
      );
      final callbackUri = Uri.tryParse(callback);
      return callbackUri == null
          ? PluginAuthenticationBrowserFailed(
              innerError: PluginAuthenticationBrowserFailureReason.invalidNativeReturn,
              stackTrace: StackTrace.current,
            )
          : PluginAuthenticationBrowserReturned(callbackUri: callbackUri);
    } on PlatformException catch (error, stackTrace) {
      return error.code == "CANCELED"
          ? const PluginAuthenticationBrowserCancelled()
          : PluginAuthenticationBrowserFailed(
              innerError: PluginAuthenticationBrowserPlatformException(code: error.code, innerError: error),
              stackTrace: stackTrace,
            );
    } on Object catch (error, stackTrace) {
      return PluginAuthenticationBrowserFailed(innerError: error, stackTrace: stackTrace);
    }
  }
}

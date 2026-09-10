sealed class const PluginAuthenticationBrowserResult();

final class const PluginAuthenticationBrowserOpened() extends PluginAuthenticationBrowserResult;

final class const PluginAuthenticationBrowserReturned({required final Uri callbackUri})
    extends PluginAuthenticationBrowserResult;

final class const PluginAuthenticationBrowserCancelled() extends PluginAuthenticationBrowserResult;

final class const PluginAuthenticationBrowserFailed({
  // Platform failures are retained for orchestration diagnostics, never shown or logged with authorization context.
  // ignore: prefer_specific_type
  required final Object innerError,
  required final StackTrace stackTrace,
}) extends PluginAuthenticationBrowserResult;

/// Native failure code is safe to log; the original platform payload may contain
/// authorization data and remains available only through [innerError].
final class const PluginAuthenticationBrowserPlatformException({
  required final String code,
  // ignore: prefer_specific_type
  required final Object innerError,
}) implements Exception {
  @override
  String toString() => "Native authentication failed ($code)";
}

/// Opens a provider login in a system-owned browser surface.
abstract interface class PluginAuthenticationBrowser() {
  /// Whether [open] waits for and returns a session-scoped callback URI.
  bool get returnsToApp;

  Future<PluginAuthenticationBrowserResult> open({
    required Uri authorizationUri,
    required String callbackScheme,
  });
}

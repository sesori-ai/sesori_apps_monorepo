/// How a launched URL should be presented to the user.
enum UrlLaunchMode() {
  /// Hand the URL to whichever app owns it — the default browser, the mail
  /// client, Discord, … The user leaves Sesori.
  externalApp,

  /// Show the URL in an in-app browser (iOS Safari view controller, Android
  /// custom tab) so the user stays in Sesori. Platforms without one degrade to
  /// [externalApp].
  inAppBrowser,
}

/// Platform-agnostic URL launcher.
///
/// Flutter apps delegate to [url_launcher]; CLI apps can use
/// `Process.run("open", [url])` or similar.
abstract class UrlLauncher() {
  /// Launch a URL in the default browser or application.
  Future<bool> launch(Uri url, {UrlLaunchMode mode = UrlLaunchMode.externalApp});
}

/// URI parts useful for diagnosing a launcher, without transcript-derived data.
extension UrlDiagnosticPresentation on Uri {
  String get diagnosticOrigin =>
      "scheme=${hasScheme ? scheme : 'none'}, host=${host.isEmpty ? 'none' : host}${hasPort ? ', port=$port' : ''}";
}

/// Retains the original failure while omitting its known outbound URI from logs.
class const ExternalLinkLaunchFailure({
  required final Uri url,
  // ignore: no_slop_linter/prefer_specific_type, preserve the original arbitrary thrown launcher failure
  required final Object innerError,
}) implements Exception {
  @override
  String toString() {
    final diagnostic = innerError.toString();
    final rawUrl = url.toString();
    final context = rawUrl.isEmpty ? diagnostic : diagnostic.replaceAll(rawUrl, "[${url.diagnosticOrigin}]");
    return "ExternalLinkLaunchFailure(${innerError.runtimeType.toString()}; $context)";
  }
}

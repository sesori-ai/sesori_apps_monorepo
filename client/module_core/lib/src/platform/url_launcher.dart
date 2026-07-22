/// How a launched URL should be presented to the user.
enum UrlLaunchMode {
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
abstract class UrlLauncher {
  /// Launch a URL in the default browser or application.
  Future<bool> launch(Uri url, {UrlLaunchMode mode = UrlLaunchMode.externalApp});
}

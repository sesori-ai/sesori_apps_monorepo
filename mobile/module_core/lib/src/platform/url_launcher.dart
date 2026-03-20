/// Platform-agnostic URL launcher.
///
/// Flutter apps delegate to [url_launcher]; CLI apps can use
/// `Process.run("open", [url])` or similar.
abstract class UrlLauncher {
  /// Launch a URL in the default browser or application.
  Future<bool> launch(Uri url);
}

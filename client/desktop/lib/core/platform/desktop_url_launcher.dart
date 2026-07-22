import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:url_launcher/url_launcher.dart";

/// Desktop [UrlLauncher] — opens URLs in the system default browser.
///
/// The OAuth browser open goes through this adapter; the bridge workspace's
/// own browser opener must never be imported by the desktop shell.
@LazySingleton(as: UrlLauncher)
class DesktopUrlLauncher implements UrlLauncher {
  /// Desktop platforms have no in-app browser surface, so
  /// [UrlLaunchMode.inAppBrowser] degrades to the system browser.
  @override
  Future<bool> launch(Uri url, {UrlLaunchMode mode = UrlLaunchMode.externalApp}) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object catch (error, stackTrace) {
      // launchUrl throws (rather than returning false) when no browser is
      // configured, e.g. a Linux box without xdg-open. Callers only see the
      // boolean, so log the cause before degrading to "could not open".
      // Host only — OAuth URLs carry one-time state in their query.
      logw("Failed to open a URL in the system browser (host: ${url.host})", error, stackTrace);
      return false;
    }
  }
}

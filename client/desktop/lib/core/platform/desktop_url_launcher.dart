import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:url_launcher/url_launcher.dart";

/// Desktop [UrlLauncher] — opens URLs in the system default browser.
///
/// The OAuth browser open goes through this adapter; the bridge workspace's
/// own browser opener must never be imported by the desktop shell.
@LazySingleton(as: UrlLauncher)
class DesktopUrlLauncher implements UrlLauncher {
  @override
  Future<bool> launch(Uri url) {
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

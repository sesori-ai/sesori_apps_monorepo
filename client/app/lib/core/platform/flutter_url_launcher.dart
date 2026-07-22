import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:url_launcher/url_launcher.dart";

@LazySingleton(as: UrlLauncher)
class FlutterUrlLauncher implements UrlLauncher {
  @override
  Future<bool> launch(Uri url, {UrlLaunchMode mode = UrlLaunchMode.externalApp}) {
    return launchUrl(
      url,
      mode: switch (mode) {
        UrlLaunchMode.externalApp => LaunchMode.externalApplication,
        UrlLaunchMode.inAppBrowser => LaunchMode.inAppBrowserView,
      },
    );
  }
}

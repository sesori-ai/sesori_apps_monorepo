import "package:sesori_dart_core/sesori_dart_core.dart";

import "di/injection.dart";

/// Desktop-shell policy for outbound settings and legal links.
Future<bool> openDesktopExternalLink({required Uri url, required UrlLaunchMode mode}) async {
  try {
    final launched = await getIt<UrlLauncher>().launch(url, mode: mode);
    if (!launched) logw("Could not open desktop external link: ${url.toString()}");
    return launched;
  } on Object catch (error, stackTrace) {
    logw("Failed to open desktop external link", error, stackTrace);
    return false;
  }
}

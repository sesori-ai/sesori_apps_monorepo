import "package:sesori_dart_core/sesori_dart_core.dart";

import "di/injection.dart";

/// Opens an external [url] (web page, mailto, etc.) via the DI-registered
/// [UrlLauncher], logging (rather than crashing) when the platform reports the
/// URL could not be handled.
///
/// This is the single shell-wide entry point for launching outbound links from
/// presentation code — markdown link taps, support/contact menu items, and the
/// login screen's terms/privacy links all funnel through here.
///
/// [mode] picks the presentation: links that hand off to another app (mail,
/// Discord) leave Sesori, while first-party pages can stay in an in-app
/// browser.
Future<void> openExternalLink({
  required Uri url,
  UrlLaunchMode mode = UrlLaunchMode.externalApp,
}) async {
  try {
    final launched = await getIt<UrlLauncher>().launch(url, mode: mode);
    if (!launched) logw("Could not open external link: ${url.toString()}");
  } on Object catch (error, stackTrace) {
    logw("Failed to open external link", error, stackTrace);
  }
}

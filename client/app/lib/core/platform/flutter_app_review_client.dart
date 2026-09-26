import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: AppReviewClient)
class FlutterAppReviewClient({required final UrlLauncher _urlLauncher}) implements AppReviewClient {
  static final _appStoreWriteReview = Uri.parse("itms-apps://itunes.apple.com/app/id6760642500?action=write-review");
  static final _playStoreApp = Uri.parse("market://details?id=com.sesori.app");
  // Devices without the Play Store app open the listing in a browser.
  static final _playStoreWeb = Uri.parse("https://play.google.com/store/apps/details?id=com.sesori.app");

  @override
  Future<void> openStoreReviewPage() async {
    final candidates = defaultTargetPlatform == TargetPlatform.iOS
        ? [_appStoreWriteReview]
        : [_playStoreApp, _playStoreWeb];
    for (final url in candidates) {
      try {
        if (await _urlLauncher.launch(url)) return;
        logw("Store page did not open (${url.diagnosticOrigin})");
      } on Object catch (error, stackTrace) {
        logw("Failed to open the store page", ExternalLinkLaunchFailure(url: url, innerError: error), stackTrace);
      }
    }
  }
}

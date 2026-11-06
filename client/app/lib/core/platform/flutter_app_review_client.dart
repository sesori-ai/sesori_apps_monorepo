import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: AppReviewClient)
class FlutterAppReviewClient({required final UrlLauncher _urlLauncher}) implements AppReviewClient {
  static const _channel = MethodChannel("com.sesori.app/app_review");
  static final _appStoreWriteReview = Uri.parse("itms-apps://itunes.apple.com/app/id6760642500?action=write-review");
  static final _playStoreApp = Uri.parse("market://details?id=com.sesori.app");
  // Devices without the Play Store app open the listing in a browser.
  static final _playStoreWeb = Uri.parse("https://play.google.com/store/apps/details?id=com.sesori.app");

  @override
  bool get allowsQuestionBeforeReview => defaultTargetPlatform != TargetPlatform.android;

  /// StoreKit on iOS, Play In-App Review on Android, both behind the native
  /// review channel.
  @override
  Future<void> requestReview() async {
    try {
      await _channel.invokeMethod<void>("requestReview");
    } on Object catch (error, stackTrace) {
      // On Android this is a build without Google Play, such as a sideloaded
      // one or a device without Play services; the review is skipped.
      loge("Failed to request the in-app review prompt", error, stackTrace);
    }
  }

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

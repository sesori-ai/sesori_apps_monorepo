import "package:sesori_dart_core/sesori_dart_core.dart" show ProductAnalyticsEventPlatform;

/// Layer-0 facts about the running app, provided by the desktop shell.
abstract interface class DesktopAppInfoSource() {
  /// The OS the app is running on, or null outside the desktop OSes.
  ProductAnalyticsEventPlatform? get platform;

  /// The version as packaged, which may carry a `+build` suffix. Throws when it
  /// can't be read.
  Future<String> readVersion();
}

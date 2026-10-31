import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@LazySingleton(as: DesktopAppInfoSource)
class FlutterDesktopAppInfoSource() implements DesktopAppInfoSource {
  @override
  ProductAnalyticsEventPlatform? get platform => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => ProductAnalyticsEventPlatform.macos,
    TargetPlatform.linux => ProductAnalyticsEventPlatform.linux,
    TargetPlatform.windows => ProductAnalyticsEventPlatform.windows,
    // Unreachable in the desktop shell.
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => null,
  };

  @override
  Future<String> readVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}

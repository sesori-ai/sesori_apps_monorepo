import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

@LazySingleton(as: DesktopAppInfoSource)
class FlutterDesktopAppInfoSource() implements DesktopAppInfoSource {
  @override
  DesktopBundleOs? get platform => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => DesktopBundleOs.macos,
    TargetPlatform.linux => DesktopBundleOs.linux,
    TargetPlatform.windows => DesktopBundleOs.windows,
    // Unreachable in the desktop shell.
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => null,
  };

  @override
  Future<String> readVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}

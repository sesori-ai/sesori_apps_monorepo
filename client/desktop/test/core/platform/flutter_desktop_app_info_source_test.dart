import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_desktop/core/platform/flutter_desktop_app_info_source.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  final source = FlutterDesktopAppInfoSource();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final (target, platform) in const [
    (TargetPlatform.macOS, DesktopBundleOs.macos),
    (TargetPlatform.linux, DesktopBundleOs.linux),
    (TargetPlatform.windows, DesktopBundleOs.windows),
  ]) {
    test("$target is $platform", () {
      debugDefaultTargetPlatformOverride = target;

      expect(source.platform, platform);
    });
  }

  for (final target in const [TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.fuchsia]) {
    test("$target has no platform", () {
      debugDefaultTargetPlatformOverride = target;

      expect(source.platform, isNull);
    });
  }

  test("reads the version as packaged", () async {
    PackageInfo.setMockInitialValues(
      appName: "Sesori",
      packageName: "com.sesori.desktop",
      version: "1.11.0+1066",
      buildNumber: "1066",
      buildSignature: "",
    );

    expect(await source.readVersion(), "1.11.0+1066");
  });
}

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_mobile/core/platform/package_info_client.dart";
import "package:sesori_mobile/core/platform/package_info_installed_app_build_source.dart";

class _MockPackageInfoClient() extends Mock implements PackageInfoClient;

void main() {
  late _MockPackageInfoClient client;
  late PackageInfoInstalledAppBuildSource source;

  setUp(() {
    client = _MockPackageInfoClient();
    source = PackageInfoInstalledAppBuildSource(packageInfoClient: client);
  });

  test("returns the PackageInfo build number", () async {
    when(() => client.read()).thenAnswer(
      (_) async => PackageInfo(
        appName: "Sesori",
        packageName: "com.sesori.app",
        version: "1.8.2",
        buildNumber: "739",
      ),
    );

    expect(await source.readBuildNumber(), "739");
  });

  test("returns unavailable when PackageInfo fails", () async {
    when(() => client.read()).thenThrow(StateError("package info unavailable"));

    expect(await source.readBuildNumber(), isNull);
  });
}

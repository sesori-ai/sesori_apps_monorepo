import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/installed_app_build_api.dart";
import "package:sesori_dart_core/src/foundation/platform/installed_app_build_source.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockInstalledAppBuildSource() extends Mock implements InstalledAppBuildSource;

void main() {
  late _MockInstalledAppBuildSource source;
  late InstalledAppBuildApi api;

  setUp(() {
    source = _MockInstalledAppBuildSource();
    api = InstalledAppBuildApi(source: source);
  });

  test("returns the platform build number", () async {
    when(() => source.readBuildNumber()).thenAnswer((_) async => "739");

    expect(await api.readBuildNumber(), "739");

    verify(() => source.readBuildNumber()).called(1);
  });

  test("preserves an unavailable source result", () async {
    when(() => source.readBuildNumber()).thenAnswer((_) async => null);

    expect(await api.readBuildNumber(), isNull);
  });

  test("passes through the version and device platform", () async {
    when(() => source.readVersion()).thenAnswer((_) async => "1.6.0");
    when(() => source.devicePlatform).thenReturn(DevicePlatform.ios);

    expect(await api.readVersion(), "1.6.0");
    expect(api.devicePlatform, DevicePlatform.ios);
  });
}

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/installed_app_build_api.dart";
import "package:sesori_dart_core/src/repositories/installed_app_build_repository.dart";
import "package:test/test.dart";

class _MockInstalledAppBuildApi() extends Mock implements InstalledAppBuildApi;

void main() {
  late _MockInstalledAppBuildApi api;
  late InstalledAppBuildRepository repository;

  setUp(() {
    api = _MockInstalledAppBuildApi();
    repository = InstalledAppBuildRepository(api: api);
  });

  test("maps a positive integer build number", () async {
    when(() => api.readBuildNumber()).thenAnswer((_) async => "739");

    expect((await repository.read())?.buildNumber, 739);
  });

  for (final rawBuildNumber in <String?>[null, "", "0", "-1", "not-a-number"]) {
    test("maps $rawBuildNumber to an unavailable installed build", () async {
      when(() => api.readBuildNumber()).thenAnswer((_) async => rawBuildNumber);

      expect(await repository.read(), isNull);
    });
  }
}

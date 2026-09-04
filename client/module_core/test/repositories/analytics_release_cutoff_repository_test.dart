import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/analytics_release_cutoff_api.dart";
import "package:sesori_dart_core/src/repositories/analytics_release_cutoff_repository.dart";
import "package:test/test.dart";

class _MockAnalyticsReleaseCutoffApi() extends Mock implements AnalyticsReleaseCutoffApi;

void main() {
  late _MockAnalyticsReleaseCutoffApi api;
  late AnalyticsReleaseCutoffRepository repository;

  setUp(() {
    api = _MockAnalyticsReleaseCutoffApi();
    repository = AnalyticsReleaseCutoffRepository(api: api);
  });

  test("maps a positive build number to the typed cutoff", () async {
    when(() => api.fetchLatestSubmittedProductionBuild()).thenAnswer((_) async => 738);

    final cutoff = await repository.fetchLatestSubmittedProductionBuild();

    expect(cutoff?.buildNumber, 738);
  });

  for (final invalidBuildNumber in [null, 0, -1]) {
    test("maps $invalidBuildNumber to an unavailable cutoff", () async {
      when(() => api.fetchLatestSubmittedProductionBuild()).thenAnswer((_) async => invalidBuildNumber);

      expect(await repository.fetchLatestSubmittedProductionBuild(), isNull);
    });
  }
}

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/android_analytics_release_cutoff_api.dart";
import "package:sesori_dart_core/src/foundation/platform/android_analytics_release_cutoff_source.dart";
import "package:test/test.dart";

class _MockAndroidAnalyticsReleaseCutoffSource() extends Mock implements AndroidAnalyticsReleaseCutoffSource;

void main() {
  late _MockAndroidAnalyticsReleaseCutoffSource source;
  late AndroidAnalyticsReleaseCutoffApi api;

  setUp(() {
    source = _MockAndroidAnalyticsReleaseCutoffSource();
    api = AndroidAnalyticsReleaseCutoffApi(source: source);
  });

  test("returns the latest submitted production build from the platform source", () async {
    when(() => source.fetchLatestSubmittedProductionBuild()).thenAnswer((_) async => 738);

    expect(await api.fetchLatestSubmittedProductionBuild(), 738);

    verify(() => source.fetchLatestSubmittedProductionBuild()).called(1);
  });

  test("preserves an unavailable source result", () async {
    when(() => source.fetchLatestSubmittedProductionBuild()).thenAnswer((_) async => null);

    expect(await api.fetchLatestSubmittedProductionBuild(), isNull);
  });
}

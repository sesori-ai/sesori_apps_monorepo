import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/repositories/analytics_release_cutoff_repository.dart";
import "package:sesori_dart_core/src/repositories/installed_app_build_repository.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_release_cutoff.dart";
import "package:sesori_dart_core/src/repositories/models/installed_app_build.dart";
import "package:sesori_dart_core/src/services/analytics_crawl_gate_service.dart";
import "package:test/test.dart";

class _MockAuthSession() extends Mock implements AuthSession;

class _MockAnalyticsReleaseCutoffRepository() extends Mock implements AnalyticsReleaseCutoffRepository;

class _MockInstalledAppBuildRepository() extends Mock implements InstalledAppBuildRepository;

void main() {
  late _MockAuthSession authSession;
  late _MockAnalyticsReleaseCutoffRepository releaseCutoffRepository;
  late _MockInstalledAppBuildRepository installedAppBuildRepository;
  late AnalyticsCrawlGateService service;

  setUp(() {
    authSession = _MockAuthSession();
    releaseCutoffRepository = _MockAnalyticsReleaseCutoffRepository();
    installedAppBuildRepository = _MockInstalledAppBuildRepository();
    service = AnalyticsCrawlGateService(
      authSession: authSession,
      releaseCutoffRepository: releaseCutoffRepository,
      installedAppBuildRepository: installedAppBuildRepository,
    );
  });

  void stubUnauthenticatedBuilds({required int installedBuild, required int releaseCutoff}) {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => false);
    when(
      () => releaseCutoffRepository.fetchLatestSubmittedProductionBuild(),
    ).thenAnswer((_) async => AnalyticsReleaseCutoff(buildNumber: releaseCutoff));
    when(
      () => installedAppBuildRepository.read(),
    ).thenAnswer((_) async => InstalledAppBuild(buildNumber: installedBuild));
  }

  test("allows an ineligible process without reading auth or build data", () async {
    expect(
      await service.resolve(eligibility: AnalyticsCrawlGateEligibility.ineligible),
      AnalyticsStoreCrawlGate.allow,
    );

    verifyNoMoreInteractions(authSession);
    verifyNoMoreInteractions(releaseCutoffRepository);
    verifyNoMoreInteractions(installedAppBuildRepository);
  });

  test("allows an authenticated testing build without reading build data", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => true);

    expect(
      await service.resolve(eligibility: AnalyticsCrawlGateEligibility.eligibleRelease),
      AnalyticsStoreCrawlGate.allow,
    );

    verifyNoMoreInteractions(releaseCutoffRepository);
    verifyNoMoreInteractions(installedAppBuildRepository);
  });

  test("suspends an unauthenticated build newer than the production submission", () async {
    stubUnauthenticatedBuilds(installedBuild: 739, releaseCutoff: 738);

    expect(
      await service.resolve(eligibility: AnalyticsCrawlGateEligibility.eligibleRelease),
      AnalyticsStoreCrawlGate.suspend,
    );
  });

  for (final installedBuild in [737, 738]) {
    test("allows unauthenticated build $installedBuild at or below the production submission", () async {
      stubUnauthenticatedBuilds(installedBuild: installedBuild, releaseCutoff: 738);

      expect(
        await service.resolve(eligibility: AnalyticsCrawlGateEligibility.eligibleRelease),
        AnalyticsStoreCrawlGate.allow,
      );
    });
  }

  test("allows when the release cutoff is unavailable", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => false);
    when(() => releaseCutoffRepository.fetchLatestSubmittedProductionBuild()).thenAnswer((_) async => null);

    expect(
      await service.resolve(eligibility: AnalyticsCrawlGateEligibility.eligibleRelease),
      AnalyticsStoreCrawlGate.allow,
    );

    verifyNoMoreInteractions(installedAppBuildRepository);
  });

  test("allows when the installed build is unavailable", () async {
    when(() => authSession.hasLocallyValidSession()).thenAnswer((_) async => false);
    when(
      () => releaseCutoffRepository.fetchLatestSubmittedProductionBuild(),
    ).thenAnswer((_) async => AnalyticsReleaseCutoff(buildNumber: 738));
    when(() => installedAppBuildRepository.read()).thenAnswer((_) async => null);

    expect(
      await service.resolve(eligibility: AnalyticsCrawlGateEligibility.eligibleRelease),
      AnalyticsStoreCrawlGate.allow,
    );
  });
}

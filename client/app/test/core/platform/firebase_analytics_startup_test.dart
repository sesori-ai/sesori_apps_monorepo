import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/firebase_analytics_startup.dart";

class MockFirebaseAnalytics() extends Mock implements FirebaseAnalytics;

void main() {
  late MockFirebaseAnalytics analytics;
  late FirebaseAnalyticsStartup startup;

  setUp(() {
    analytics = MockFirebaseAnalytics();
    startup = FirebaseAnalyticsStartup(analytics: analytics);
    when(() => analytics.setAnalyticsCollectionEnabled(any())).thenAnswer((_) async {});
    when(
      () => analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      ),
    ).thenAnswer((_) async {});
  });

  test("enables an eligible release only after the crawl gate allows it", () async {
    final capability = await startup.prepare(ineligibilityReason: null);

    expect(capability, isA<AnalyticsRuntimeEnabled>());
    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
    verifyNoMoreInteractions(analytics);

    await startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow);

    verifyInOrder([
      () => analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      ),
      () => analytics.setAnalyticsCollectionEnabled(true),
    ]);
    verifyNoMoreInteractions(analytics);
  });

  test("keeps collection off for ineligible processes", () async {
    for (final reason in [
      AnalyticsRuntimeDisabledReason.debugOrProfile,
      AnalyticsRuntimeDisabledReason.unsupportedPlatform,
    ]) {
      final capability = await startup.prepare(ineligibilityReason: reason);

      expect(
        capability,
        isA<AnalyticsRuntimeDisabled>().having((value) => value.reason, "reason", reason),
      );
      await startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow);
    }

    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(2);
    verifyNoMoreInteractions(analytics);
  });

  test("a store-crawl suspension keeps the SDK off with an operational runtime", () async {
    final capability = await startup.prepare(ineligibilityReason: null);
    await startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.suspend);

    expect(capability, isA<AnalyticsRuntimeEnabled>());
    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
    verifyNoMoreInteractions(analytics);
  });

  test("interactive authentication lifts the resolved store-crawl suspension once", () async {
    await startup.prepare(ineligibilityReason: null);
    await startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.suspend);

    await startup.activateAfterInteractiveAuthentication();
    await startup.activateAfterInteractiveAuthentication();

    verifyInOrder([
      () => analytics.setAnalyticsCollectionEnabled(false),
      () => analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      ),
      () => analytics.setAnalyticsCollectionEnabled(true),
    ]);
    verifyNoMoreInteractions(analytics);
  });

  test("interactive authentication lifts a pending gate before it resolves", () async {
    await startup.prepare(ineligibilityReason: null);

    await startup.activateAfterInteractiveAuthentication();
    await startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.suspend);

    verifyInOrder([
      () => analytics.setAnalyticsCollectionEnabled(false),
      () => analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      ),
      () => analytics.setAnalyticsCollectionEnabled(true),
    ]);
    verifyNoMoreInteractions(analytics);
  });

  test("activation after an allowing gate is a no-op", () async {
    await startup.prepare(ineligibilityReason: null);
    await startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow);
    clearInteractions(analytics);

    await startup.activateAfterInteractiveAuthentication();

    verifyZeroInteractions(analytics);
  });

  test("fails closed when collection cannot be suspended", () async {
    when(
      () => analytics.setAnalyticsCollectionEnabled(false),
    ).thenAnswer((_) async => throw StateError("suspend failed"));

    final capability = await startup.prepare(ineligibilityReason: null);

    expect(
      capability,
      isA<AnalyticsRuntimeDisabled>().having(
        (value) => value.reason,
        "reason",
        AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      ),
    );
    await startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow);
    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
    verifyNoMoreInteractions(analytics);
  });

  test("keeps collection off and permits a later retry when enabling fails", () async {
    when(
      () => analytics.setAnalyticsCollectionEnabled(true),
    ).thenAnswer((_) async => throw StateError("enable failed"));

    final capability = await startup.prepare(ineligibilityReason: null);
    await startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow);
    await startup.activateAfterInteractiveAuthentication();

    expect(capability, isA<AnalyticsRuntimeEnabled>());
    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
    verify(
      () => analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      ),
    ).called(2);
    verify(() => analytics.setAnalyticsCollectionEnabled(true)).called(2);
    verifyNoMoreInteractions(analytics);
  });
}

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
    when(() => analytics.setUserId(id: null)).thenAnswer((_) async {});
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

  test("enables release collection only after suspension, identity clear, and consent", () async {
    final capability = await startup.configure(disabledReasonAfterSuccess: null);

    expect(capability, isA<AnalyticsRuntimeEnabled>());
    verifyInOrder([
      () => analytics.setAnalyticsCollectionEnabled(false),
      () => analytics.setUserId(id: null),
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

  test("keeps collection off for debug and automated test environments", () async {
    for (final reason in [
      AnalyticsRuntimeDisabledReason.debugOrProfile,
      AnalyticsRuntimeDisabledReason.automatedTestEnvironment,
    ]) {
      final capability = await startup.configure(disabledReasonAfterSuccess: reason);

      expect(
        capability,
        isA<AnalyticsRuntimeDisabled>().having((value) => value.reason, "reason", reason),
      );
    }

    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(2);
    verify(() => analytics.setUserId(id: null)).called(2);
    verifyNoMoreInteractions(analytics);
  });

  test("fails closed when collection cannot be suspended", () async {
    when(
      () => analytics.setAnalyticsCollectionEnabled(false),
    ).thenAnswer((_) async => throw StateError("suspend failed"));

    final capability = await startup.configure(disabledReasonAfterSuccess: null);

    expect(
      capability,
      isA<AnalyticsRuntimeDisabled>().having(
        (value) => value.reason,
        "reason",
        AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      ),
    );
    verify(() => analytics.setAnalyticsCollectionEnabled(false)).called(1);
    verifyNoMoreInteractions(analytics);
  });

  test("does not re-enable collection when the legacy identity clear fails", () async {
    when(
      () => analytics.setUserId(id: null),
    ).thenAnswer((_) async => throw StateError("clear failed"));

    final capability = await startup.configure(disabledReasonAfterSuccess: null);

    expect(
      capability,
      isA<AnalyticsRuntimeDisabled>().having(
        (value) => value.reason,
        "reason",
        AnalyticsRuntimeDisabledReason.identitySafetyPreconditionFailed,
      ),
    );
    verifyInOrder([
      () => analytics.setAnalyticsCollectionEnabled(false),
      () => analytics.setUserId(id: null),
    ]);
    verifyNoMoreInteractions(analytics);
  });

  test("fails closed when release collection cannot be enabled", () async {
    when(
      () => analytics.setAnalyticsCollectionEnabled(true),
    ).thenAnswer((_) async => throw StateError("enable failed"));

    final capability = await startup.configure(disabledReasonAfterSuccess: null);

    expect(
      capability,
      isA<AnalyticsRuntimeDisabled>().having(
        (value) => value.reason,
        "reason",
        AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      ),
    );
    verifyInOrder([
      () => analytics.setAnalyticsCollectionEnabled(false),
      () => analytics.setUserId(id: null),
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
}

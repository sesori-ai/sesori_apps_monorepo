import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/firebase_analytics_identity_migration.dart";

class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  late MockFirebaseAnalytics analytics;
  late FirebaseAnalyticsIdentityMigration migration;

  setUp(() {
    analytics = MockFirebaseAnalytics();
    migration = FirebaseAnalyticsIdentityMigration(analytics: analytics);
    when(() => analytics.setUserId(id: null)).thenAnswer((_) async {});
  });

  test("returns enabled capability after clearing the legacy identity", () async {
    final capability = await migration.clearLegacyIdentity(
      disabledReasonAfterSuccess: null,
    );

    expect(capability, isA<AnalyticsRuntimeEnabled>());
    verify(() => analytics.setUserId(id: null)).called(1);
    verifyNoMoreInteractions(analytics);
  });

  test("preserves the requested disabled capability after a successful clear", () async {
    final capability = await migration.clearLegacyIdentity(
      disabledReasonAfterSuccess: AnalyticsRuntimeDisabledReason.debugOrProfile,
    );

    expect(
      capability,
      isA<AnalyticsRuntimeDisabled>().having(
        (value) => value.reason,
        "reason",
        AnalyticsRuntimeDisabledReason.debugOrProfile,
      ),
    );
    verify(() => analytics.setUserId(id: null)).called(1);
    verifyNoMoreInteractions(analytics);
  });

  test("returns legacy-clear-failed capability when Firebase rejects the clear", () async {
    when(
      () => analytics.setUserId(id: null),
    ).thenAnswer((_) async => throw StateError("clear failed"));

    final capability = await migration.clearLegacyIdentity(
      disabledReasonAfterSuccess: null,
    );

    expect(
      capability,
      isA<AnalyticsRuntimeDisabled>().having(
        (value) => value.reason,
        "reason",
        AnalyticsRuntimeDisabledReason.legacyIdentityClearFailed,
      ),
    );
    verify(() => analytics.setUserId(id: null)).called(1);
    verifyNoMoreInteractions(analytics);
  });
}

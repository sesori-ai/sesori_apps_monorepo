import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/platform/firebase_analytics_identity_migration.dart";

class MockFirebaseAnalytics() extends Mock implements FirebaseAnalytics;

void main() {
  late MockFirebaseAnalytics analytics;
  late FirebaseAnalyticsIdentityMigration migration;

  setUp(() {
    analytics = MockFirebaseAnalytics();
    migration = FirebaseAnalyticsIdentityMigration(analytics: analytics);
    when(() => analytics.setUserId(id: null)).thenAnswer((_) async {});
  });

  test("confirms the clear when Firebase accepts it", () async {
    expect(await migration.clearLegacyIdentity(), isTrue);
    verify(() => analytics.setUserId(id: null)).called(1);
    verifyNoMoreInteractions(analytics);
  });

  test("reports an unconfirmed clear when Firebase rejects it", () async {
    when(
      () => analytics.setUserId(id: null),
    ).thenAnswer((_) async => throw StateError("clear failed"));

    expect(await migration.clearLegacyIdentity(), isFalse);
    verify(() => analytics.setUserId(id: null)).called(1);
    verifyNoMoreInteractions(analytics);
  });
}

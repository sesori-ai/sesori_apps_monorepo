import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/analytics/analytics_event.dart";
import "package:sesori_mobile/core/analytics/firebase_analytics_reporter.dart";

import "../../helpers/test_helpers.dart";

void main() {
  late MockFirebaseAnalytics mockAnalytics;
  late FirebaseAnalyticsReporter reporter;

  setUp(() {
    mockAnalytics = MockFirebaseAnalytics();
    reporter = FirebaseAnalyticsReporter(analytics: mockAnalytics);

    when(
      () => mockAnalytics.logEvent(name: any(named: "name"), parameters: any(named: "parameters")),
    ).thenAnswer((_) async {});
  });

  group("FirebaseAnalyticsReporter", () {
    // These tests also pin the GA4 wire names/values, so renaming a union case
    // or enum identifier cannot silently change what reaches analytics.
    test("sends the union wire name with the case fields as parameters", () async {
      await reporter.logEvent(
        event: const AnalyticsEvent.supportLinkOpened(channel: SupportChannel.email),
      );

      verify(
        () => mockAnalytics.logEvent(
          name: "onboarding_support_link_opened",
          parameters: {"channel": "email"},
        ),
      ).called(1);
    });

    test("sends a field-less event with null parameters", () async {
      await reporter.logEvent(event: const AnalyticsEvent.needHelpMenuOpened());

      verify(
        () => mockAnalytics.logEvent(name: "onboarding_need_help_opened", parameters: null),
      ).called(1);
    });

    test("swallows analytics errors without crashing", () async {
      when(
        () =>
            mockAnalytics.logEvent(name: any(named: "name"), parameters: any(named: "parameters")),
      ).thenThrow(Exception("analytics crashed"));

      // Test passes if no exception propagates out of the reporter.
      await reporter.logEvent(event: const AnalyticsEvent.needHelpMenuOpened());

      verify(
        () => mockAnalytics.logEvent(name: "onboarding_need_help_opened", parameters: null),
      ).called(1);
    });
  });
}

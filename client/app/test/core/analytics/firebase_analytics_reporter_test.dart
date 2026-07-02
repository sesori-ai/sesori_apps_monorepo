import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/analytics/firebase_analytics_reporter.dart";

import "../../helpers/test_helpers.dart";

void main() {
  late MockFirebaseAnalytics mockAnalytics;
  late FirebaseAnalyticsReporter reporter;

  setUp(() {
    mockAnalytics = MockFirebaseAnalytics();
    reporter = FirebaseAnalyticsReporter(analytics: mockAnalytics);
  });

  group("FirebaseAnalyticsReporter", () {
    test("forwards event name and parameters to Firebase Analytics", () async {
      when(
        () => mockAnalytics.logEvent(name: any(named: "name"), parameters: any(named: "parameters")),
      ).thenAnswer((_) async {});

      await reporter.logEvent(name: "test_event", parameters: {"channel": "email"});

      verify(() => mockAnalytics.logEvent(name: "test_event", parameters: {"channel": "email"})).called(1);
    });

    test("forwards a parameterless event with null parameters", () async {
      when(
        () => mockAnalytics.logEvent(name: any(named: "name"), parameters: any(named: "parameters")),
      ).thenAnswer((_) async {});

      await reporter.logEvent(name: "test_event", parameters: null);

      verify(() => mockAnalytics.logEvent(name: "test_event", parameters: null)).called(1);
    });

    test("swallows analytics errors without crashing", () async {
      when(
        () => mockAnalytics.logEvent(name: any(named: "name"), parameters: any(named: "parameters")),
      ).thenThrow(Exception("analytics crashed"));

      // Test passes if no exception propagates out of the reporter.
      await reporter.logEvent(name: "test_event", parameters: null);

      verify(() => mockAnalytics.logEvent(name: "test_event", parameters: null)).called(1);
    });
  });
}

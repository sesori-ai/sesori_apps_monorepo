import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/singular/singular_attribution_client.dart";
import "package:sesori_mobile/core/platform/singular/singular_static_adapter.dart";
import "package:sesori_mobile/core/platform/singular_attribution_startup.dart";
import "package:singular_flutter_sdk/events.dart";

SingularAttributionStartup _eligibleStartup({required SingularStaticAdapter singular}) =>
    SingularAttributionStartup(singular: singular)
      ..prepare(
        isSupportedPlatform: true,
        ineligibilityReason: null,
        sdkKey: "sdk-key",
        sdkSecret: "sdk-secret",
      )
      ..applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("maps the closed attribution catalog to Singular event names", () async {
    final eventNames = <String>[];
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final client = SingularAttributionClient(
      startup: _eligibleStartup(singular: singular),
      singular: singular,
    );

    expect(client.isReady, isTrue);
    for (final event in AttributionEvent.values) {
      await client.logEvent(event: event);
    }

    expect(eventNames, [
      Events.sngCompleteRegistration,
      Events.sngLogin,
      "bridge_paired",
      "first_session_run",
    ]);
  });

  test("custom events cannot start Singular while the crawl gate is unresolved", () async {
    var startCount = 0;
    final eventNames = <String>[];
    final singular = SingularStaticAdapter.test(
      start: (_) => startCount += 1,
      event: eventNames.add,
    );
    final client = SingularAttributionClient(
      startup: SingularAttributionStartup(singular: singular)
        ..prepare(
          isSupportedPlatform: true,
          ineligibilityReason: null,
          sdkKey: "sdk-key",
          sdkSecret: "sdk-secret",
        ),
      singular: singular,
    );

    await client.logEvent(event: AttributionEvent.bridgePaired);

    expect(client.isReady, isFalse);
    expect(startCount, 0);
    expect(eventNames, isEmpty);
  });

  test("interactive authentication starts deferred attribution before reporting", () async {
    var startCount = 0;
    final eventNames = <String>[];
    final singular = SingularStaticAdapter.test(
      start: (_) => startCount += 1,
      event: eventNames.add,
    );
    final startup = SingularAttributionStartup(singular: singular)
      ..prepare(
        isSupportedPlatform: true,
        ineligibilityReason: null,
        sdkKey: "sdk-key",
        sdkSecret: "sdk-secret",
      )
      ..applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.suspend);
    final client = SingularAttributionClient(startup: startup, singular: singular);
    final readiness = expectLater(client.readinessStream, emits(isNull));

    await client.logEvent(event: AttributionEvent.accountLogin);
    await readiness;
    await client.logEvent(event: AttributionEvent.firstSessionRun);

    expect(client.isReady, isTrue);
    expect(startCount, 1);
    expect(eventNames, [Events.sngLogin, "first_session_run"]);
  });
}

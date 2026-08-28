import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/singular/singular_attribution_client.dart";
import "package:sesori_mobile/core/platform/singular/singular_static_adapter.dart";
import "package:sesori_mobile/core/platform/singular_attribution_startup.dart";
import "package:singular_flutter_sdk/events.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("maps closed attribution outcomes to Singular standard events", () async {
    final eventNames = <String>[];
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final startup = SingularAttributionStartup(singular: singular)
      ..start(
        isSupportedPlatform: true,
        ineligibilityReason: null,
        deferUntilInteractiveAuthentication: false,
        sdkKey: "sdk-key",
        sdkSecret: "sdk-secret",
      );
    final client = SingularAttributionClient(startup: startup, singular: singular);

    await client.logEvent(event: AttributionEvent.accountCreated);
    await client.logEvent(event: AttributionEvent.accountLogin);

    expect(eventNames, [Events.sngCompleteRegistration, Events.sngLogin]);
  });

  test("does not report events when Singular did not start", () async {
    final eventNames = <String>[];
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final client = SingularAttributionClient(
      startup: SingularAttributionStartup(singular: singular),
      singular: singular,
    );

    await client.logEvent(event: AttributionEvent.accountLogin);

    expect(eventNames, isEmpty);
  });

  test("starts deferred attribution before reporting an authenticated event", () async {
    var startCount = 0;
    final eventNames = <String>[];
    final singular = SingularStaticAdapter.test(
      start: (_) {
        startCount += 1;
      },
      event: eventNames.add,
    );
    final startup = SingularAttributionStartup(singular: singular)
      ..start(
        isSupportedPlatform: true,
        ineligibilityReason: null,
        deferUntilInteractiveAuthentication: true,
        sdkKey: "sdk-key",
        sdkSecret: "sdk-secret",
      );
    final client = SingularAttributionClient(startup: startup, singular: singular);

    await client.logEvent(event: AttributionEvent.accountLogin);

    expect(startCount, 1);
    expect(eventNames, [Events.sngLogin]);
  });
}

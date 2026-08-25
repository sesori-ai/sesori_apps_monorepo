import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/singular/singular_attribution_client.dart";
import "package:sesori_mobile/core/platform/singular/singular_static_adapter.dart";
import "package:singular_flutter_sdk/events.dart";
import "package:singular_flutter_sdk/singular_config.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("maps closed attribution outcomes to Singular standard events", () async {
    final eventNames = <String>[];
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final client = SingularAttributionClient(singular: singular);
    singular.start(config: SingularConfig("sdk-key", "sdk-secret"));

    await client.logEvent(event: AttributionEvent.accountCreated);
    await client.logEvent(event: AttributionEvent.accountLogin);

    expect(eventNames, [Events.sngCompleteRegistration, Events.sngLogin]);
  });

  test("does not report events when Singular did not start", () async {
    final eventNames = <String>[];
    final client = SingularAttributionClient(
      singular: SingularStaticAdapter.test(start: (_) {}, event: eventNames.add),
    );

    await client.logEvent(event: AttributionEvent.accountLogin);

    expect(eventNames, isEmpty);
  });
}

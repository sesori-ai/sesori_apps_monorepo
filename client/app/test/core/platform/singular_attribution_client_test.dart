import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/singular/singular_attribution_client.dart";
import "package:sesori_mobile/core/platform/singular/singular_static_adapter.dart";
import "package:sesori_mobile/core/platform/singular_attribution_startup.dart";
import "package:singular_flutter_sdk/events.dart";

class _MemorySecureStorage() implements SecureStorage {
  final values = <String, String>{};
  int reads = 0;
  int writes = 0;
  Completer<String?>? readGate;
  bool throwOnRead = false;

  @override
  Future<String?> read({required String key}) async {
    reads += 1;
    if (throwOnRead) throw StateError("storage unavailable");
    final gate = readGate;
    return gate == null ? values[key] : await gate.future;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writes += 1;
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

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

  test("maps closed authentication outcomes to repeatable Singular standard events", () async {
    final eventNames = <String>[];
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final client = SingularAttributionClient(
      startup: _eligibleStartup(singular: singular),
      singular: singular,
      storage: _MemorySecureStorage(),
    );

    await client.logEvent(event: AttributionEvent.accountCreated);
    await client.logEvent(event: AttributionEvent.accountLogin);
    await client.logEvent(event: AttributionEvent.accountLogin);

    expect(eventNames, [Events.sngCompleteRegistration, Events.sngLogin, Events.sngLogin]);
  });

  test("persists the two parameter-free activation events at most once", () async {
    final eventNames = <String>[];
    final storage = _MemorySecureStorage();
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final startup = _eligibleStartup(singular: singular);
    final client = SingularAttributionClient(startup: startup, singular: singular, storage: storage);

    await client.logEvent(event: AttributionEvent.bridgePaired);
    await client.logEvent(event: AttributionEvent.bridgePaired);
    await client.logEvent(event: AttributionEvent.firstSessionRun);
    await client.logEvent(event: AttributionEvent.firstSessionRun);

    final restartedClient = SingularAttributionClient(startup: startup, singular: singular, storage: storage);
    await restartedClient.logEvent(event: AttributionEvent.bridgePaired);
    await restartedClient.logEvent(event: AttributionEvent.firstSessionRun);

    expect(eventNames, ["bridge_paired", "first_session_run"]);
    expect(storage.writes, 2);
  });

  test("coalesces concurrent first claims without duplicate SDK calls", () async {
    final eventNames = <String>[];
    final storage = _MemorySecureStorage()..readGate = Completer<String?>();
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final client = SingularAttributionClient(
      startup: _eligibleStartup(singular: singular),
      singular: singular,
      storage: storage,
    );

    final first = client.logEvent(event: AttributionEvent.bridgePaired);
    final second = client.logEvent(event: AttributionEvent.bridgePaired);
    await Future<void>.delayed(Duration.zero);
    storage.readGate!.complete(null);
    await Future.wait([first, second]);

    expect(eventNames, ["bridge_paired"]);
    expect(storage.reads, 1);
    expect(storage.writes, 1);
  });

  test("does not claim or report events when Singular did not start", () async {
    final eventNames = <String>[];
    final storage = _MemorySecureStorage();
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final client = SingularAttributionClient(
      startup: SingularAttributionStartup(singular: singular),
      singular: singular,
      storage: storage,
    );

    await client.logEvent(event: AttributionEvent.bridgePaired);

    expect(eventNames, isEmpty);
    expect(storage.reads, 0);
    expect(storage.writes, 0);
  });

  test("storage uncertainty fails closed rather than risking a duplicate", () async {
    final eventNames = <String>[];
    final storage = _MemorySecureStorage()..throwOnRead = true;
    final singular = SingularStaticAdapter.test(start: (_) {}, event: eventNames.add);
    final client = SingularAttributionClient(
      startup: _eligibleStartup(singular: singular),
      singular: singular,
      storage: storage,
    );

    await client.logEvent(event: AttributionEvent.firstSessionRun);
    await client.logEvent(event: AttributionEvent.firstSessionRun);

    expect(eventNames, isEmpty);
    expect(storage.reads, 1);
    expect(storage.writes, 0);
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
      ..prepare(
        isSupportedPlatform: true,
        ineligibilityReason: null,
        sdkKey: "sdk-key",
        sdkSecret: "sdk-secret",
      )
      ..applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.suspend);
    final client = SingularAttributionClient(
      startup: startup,
      singular: singular,
      storage: _MemorySecureStorage(),
    );

    await client.logEvent(event: AttributionEvent.accountLogin);

    expect(startCount, 1);
    expect(eventNames, [Events.sngLogin]);
  });
}

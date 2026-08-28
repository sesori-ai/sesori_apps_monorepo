import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/singular/singular_static_adapter.dart";
import "package:sesori_mobile/core/platform/singular_attribution_startup.dart";
import "package:singular_flutter_sdk/events.dart";
import "package:singular_flutter_sdk/singular_config.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SingularConfig> startedConfigs;
  late List<String> eventNames;
  late SingularStaticAdapter singular;
  late SingularAttributionStartup startup;

  setUp(() {
    startedConfigs = [];
    eventNames = [];
    singular = SingularStaticAdapter.test(start: startedConfigs.add, event: eventNames.add);
    startup = SingularAttributionStartup(singular: singular);
  });

  void prepareEligibleStartup() {
    startup.prepare(
      isSupportedPlatform: true,
      ineligibilityReason: null,
      sdkKey: "test-sdk-key",
      sdkSecret: "test-sdk-secret",
    );
  }

  test("starts an eligible supported build after the crawl gate allows it", () {
    prepareEligibleStartup();

    expect(startedConfigs, isEmpty);
    startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow);

    expect(startedConfigs, hasLength(1));
    expect(
      startedConfigs.single.toMap,
      containsPair("apiKey", "test-sdk-key"),
    );
    expect(
      startedConfigs.single.toMap,
      containsPair("secretKey", "test-sdk-secret"),
    );
    expect(startedConfigs.single.toMap, containsPair("limitAdvertisingIdentifiers", true));
    expect(startedConfigs.single.toMap, containsPair("limitDataSharing", true));
    expect(startedConfigs.single.toMap, containsPair("skAdNetworkEnabled", true));
    expect(startedConfigs.single.toMap, containsPair("enableLogging", false));
    expect(startedConfigs.single.toMap, isNot(contains("customUserId")));
  });

  test("does not start on unsupported platforms or ineligible builds", () {
    startup.prepare(
      isSupportedPlatform: false,
      ineligibilityReason: null,
      sdkKey: "test-sdk-key",
      sdkSecret: "test-sdk-secret",
    );
    startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow);
    startup.prepare(
      isSupportedPlatform: true,
      ineligibilityReason: AnalyticsRuntimeDisabledReason.debugOrProfile,
      sdkKey: "test-sdk-key",
      sdkSecret: "test-sdk-secret",
    );
    startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.suspend);

    expect(startup.activateAfterInteractiveAuthentication(), isFalse);
    expect(startedConfigs, isEmpty);
    expect(eventNames, isEmpty);
  });

  test("defers a crawl-gated startup until interactive authentication reports an event", () {
    prepareEligibleStartup();
    startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.suspend);

    expect(startedConfigs, isEmpty);

    expect(startup.activateAfterInteractiveAuthentication(), isTrue);
    singular.event(eventName: Events.sngLogin);

    expect(startedConfigs, hasLength(1));
    expect(eventNames, [Events.sngLogin]);
  });

  test("interactive authentication can start Singular while the gate is pending", () {
    prepareEligibleStartup();

    expect(startup.activateAfterInteractiveAuthentication(), isTrue);
    singular.event(eventName: Events.sngLogin);
    startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.suspend);

    expect(startedConfigs, hasLength(1));
    expect(eventNames, [Events.sngLogin]);
  });

  test("contains SDK startup failures", () {
    startup = SingularAttributionStartup(
      singular: SingularStaticAdapter.test(
        start: (_) => throw StateError("native startup failed"),
        event: (_) {},
      ),
    );
    prepareEligibleStartup();

    expect(
      () => startup.applyCrawlGate(crawlGate: AnalyticsStoreCrawlGate.allow),
      returnsNormally,
    );
    expect(startup.activateAfterInteractiveAuthentication(), isFalse);
  });
}

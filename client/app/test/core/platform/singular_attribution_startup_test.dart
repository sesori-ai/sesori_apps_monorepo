import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/platform/singular/singular_static_adapter.dart";
import "package:sesori_mobile/core/platform/singular_attribution_startup.dart";
import "package:singular_flutter_sdk/singular_config.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SingularConfig> startedConfigs;
  late SingularAttributionStartup startup;

  setUp(() {
    startedConfigs = [];
    startup = SingularAttributionStartup(
      singular: SingularStaticAdapter.test(start: startedConfigs.add),
    );
  });

  test("starts an eligible supported build with privacy-minimized configuration", () {
    final status = startup.start(
      isSupportedPlatform: true,
      isEligibleBuild: true,
      sdkKey: "test-sdk-key",
      sdkSecret: "test-sdk-secret",
    );

    expect(status, SingularAttributionStartupStatus.started);
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
    expect(
      startup.start(
        isSupportedPlatform: false,
        isEligibleBuild: true,
        sdkKey: "test-sdk-key",
        sdkSecret: "test-sdk-secret",
      ),
      SingularAttributionStartupStatus.unsupportedPlatform,
    );
    expect(
      startup.start(
        isSupportedPlatform: true,
        isEligibleBuild: false,
        sdkKey: "test-sdk-key",
        sdkSecret: "test-sdk-secret",
      ),
      SingularAttributionStartupStatus.ineligibleBuild,
    );
    expect(startedConfigs, isEmpty);
  });

  test("does not start when credentials are absent or incomplete", () {
    expect(
      startup.start(
        isSupportedPlatform: true,
        isEligibleBuild: true,
        sdkKey: null,
        sdkSecret: null,
      ),
      SingularAttributionStartupStatus.missingCredentials,
    );
    expect(
      startup.start(
        isSupportedPlatform: true,
        isEligibleBuild: true,
        sdkKey: "test-sdk-key",
        sdkSecret: null,
      ),
      SingularAttributionStartupStatus.invalidCredentials,
    );
    expect(
      startup.start(
        isSupportedPlatform: true,
        isEligibleBuild: true,
        sdkKey: null,
        sdkSecret: "test-sdk-secret",
      ),
      SingularAttributionStartupStatus.invalidCredentials,
    );
    expect(startedConfigs, isEmpty);
  });

  test("contains SDK startup failures", () {
    startup = SingularAttributionStartup(
      singular: SingularStaticAdapter.test(
        start: (_) => throw StateError("native startup failed"),
      ),
    );

    final status = startup.start(
      isSupportedPlatform: true,
      isEligibleBuild: true,
      sdkKey: "test-sdk-key",
      sdkSecret: "test-sdk-secret",
    );

    expect(status, SingularAttributionStartupStatus.failed);
  });
}

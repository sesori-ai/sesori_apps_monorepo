import "package:sesori_bridge/src/routing/get_plugin_management_handler.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  test("handles only GET /plugin/management", () {
    final handler = GetPluginManagementHandler(
      lifecycleService: _FakePluginLifecycleService(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );

    expect(handler.canHandle(makeRequest("GET", "/plugin/management")), isTrue);
    expect(handler.canHandle(makeRequest("POST", "/plugin/management")), isFalse);
    expect(handler.canHandle(makeRequest("GET", "/plugin/setup")), isFalse);
  });

  test("returns the current lifecycle service snapshot stamped with the bridge identity", () async {
    final response =
        await GetPluginManagementHandler(
          lifecycleService: _FakePluginLifecycleService(),
          bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
        ).handleInternal(
          makeRequest("GET", "/plugin/management"),
          pathParams: const {},
          queryParams: const {},
          fragment: null,
        );

    expect(response.status, 200);
    expect(PluginManagementResponse.fromJson(jsonDecodeMap(response.body!)), _response.copyWith(bridgeId: "br_test1234"));
  });
}

const _response = PluginManagementResponse(
  snapshotToken: "snapshot-token",
  bridgeId: null,
  defaultPluginId: "one",
  defaultIdleTimeoutMins: 10,
  plugins: [
    PluginManagementMetadata(
      setup: PluginSetupMetadata(
        id: "one",
        displayName: "One",
        state: PluginSetupState.ready,
        actionHint: null,
      ),
      runtimeState: PluginRuntimeState.dormant,
      workState: PluginManagementWorkState.unknown,
      idleTimeoutMins: 10,
      hasIdleTimeoutOverride: false,
      actionHint: null,
    ),
  ],
);

class _FakePluginLifecycleService implements PluginLifecycleService {
  @override
  PluginManagementResponse get managementSnapshot => _response;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

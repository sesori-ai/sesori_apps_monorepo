import "package:sesori_bridge/src/routing/get_plugins_handler.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  test("advertises session options and file uploads beside the selectable plugins", () async {
    final response = await GetPluginsHandler(
      lifecycleService: _FakePluginLifecycleService(),
      bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
    ).routeForTest(makeRequest("GET", "/plugin"));

    expect(response.status, 200);
    expect(
      PluginListResponse.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
      const PluginListResponse(
        plugins: _plugins,
        bridgeId: "br_test1234",
        supportsSessionOptions: true,
        supportsFileUploads: true,
      ),
    );
  });
}

const _plugins = [
  PluginMetadata(
    id: "one",
    displayName: "One",
    isDefault: true,
    state: PluginLifecycleState.ready,
    actionHint: null,
    failureBlock: null,
    mcpScopes: null,
    supportsPromptAttachments: true,
    failureReason: null,
  ),
];

class _FakePluginLifecycleService() implements PluginLifecycleService {
  @override
  List<PluginMetadata> get selectableMetadataSnapshot => _plugins;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

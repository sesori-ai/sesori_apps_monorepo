import "dart:convert";

import "package:sesori_bridge/src/routing/patch_plugin_idle_timeout_handler.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "routing_test_helpers.dart";

void main() {
  PatchPluginIdleTimeoutHandler buildHandler({required _FakePluginLifecycleService service}) =>
      PatchPluginIdleTimeoutHandler(
        lifecycleService: service,
        bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
      );

  test("PatchPluginIdleTimeoutHandler handles only PATCH /plugin/idle-timeout", () {
    final handler = buildHandler(service: _FakePluginLifecycleService());

    expect(handler.canHandle(makeRequest("PATCH", "/plugin/idle-timeout")), isTrue);
    expect(handler.canHandle(makeRequest("GET", "/plugin/idle-timeout")), isFalse);
    expect(handler.canHandle(makeRequest("PATCH", "/plugin/management")), isFalse);
  });

  test("PatchPluginIdleTimeoutHandler returns the updated management snapshot", () async {
    final service = _FakePluginLifecycleService();
    final response = await buildHandler(service: service).handleInternal(
      makeRequest(
        "PATCH",
        "/plugin/idle-timeout",
        body: jsonEncode(const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30).toJson()),
      ),
      pathParams: const {},
      queryParams: const {},
      fragment: null,
    );

    expect(response.status, 200);
    expect(service.receivedRequest, const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30));
    expect(
      PluginManagementResponse.fromJson(jsonDecodeMap(response.body!)),
      _response.copyWith(bridgeId: "br_test1234"),
    );
  });

  test("PatchPluginIdleTimeoutHandler maps invalid, unknown, and failed writes", () async {
    final service = _FakePluginLifecycleService();
    final handler = buildHandler(service: service);

    final invalid = await handler.handleInternal(
      makeRequest(
        "PATCH",
        "/plugin/idle-timeout",
        body: jsonEncode(const {"type": "setOverride", "pluginId": "one", "idleTimeoutMins": 1.5}),
      ),
      pathParams: const {},
      queryParams: const {},
      fragment: null,
    );
    service.error = const PluginManagementPluginNotFoundException("missing");
    final unknown = await handler.handleInternal(
      makeRequest(
        "PATCH",
        "/plugin/idle-timeout",
        body: jsonEncode(const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "missing").toJson()),
      ),
      pathParams: const {},
      queryParams: const {},
      fragment: null,
    );
    service.error = StateError("disk full");
    final failed = await handler.handleInternal(
      makeRequest(
        "PATCH",
        "/plugin/idle-timeout",
        body: jsonEncode(const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "one").toJson()),
      ),
      pathParams: const {},
      queryParams: const {},
      fragment: null,
    );

    expect(invalid.status, 400);
    expect(unknown.status, 404);
    expect(failed.status, 500);
  });
}

const _response = PluginManagementResponse(
  snapshotToken: "snapshot-token",
  bridgeId: null,
  defaultPluginId: "one",
  defaultIdleTimeoutMins: 30,
  plugins: [],
);

class _FakePluginLifecycleService implements PluginLifecycleService {
  PluginIdleTimeoutUpdateRequest? receivedRequest;
  Object? error;

  @override
  Future<PluginManagementResponse> updateIdleTimeout({required PluginIdleTimeoutUpdateRequest request}) async {
    receivedRequest = request;
    final currentError = error;
    if (currentError != null) throw currentError;
    return _response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import "dart:convert";

import "package:sesori_bridge/src/routing/post_plugin_lifecycle_command_handler.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  PostPluginLifecycleCommandHandler buildHandler({required _FakePluginLifecycleService service}) =>
      PostPluginLifecycleCommandHandler(lifecycleService: service);

  test("PostPluginLifecycleCommandHandler handles only plugin command posts", () {
    final handler = buildHandler(service: _FakePluginLifecycleService());

    expect(handler.canHandle(makeRequest("POST", "/plugin/one/command")), isTrue);
    expect(handler.canHandle(makeRequest("GET", "/plugin/one/command")), isFalse);
    expect(handler.canHandle(makeRequest("POST", "/plugin/command")), isFalse);
  });

  test("PostPluginLifecycleCommandHandler dispatches a typed disable command", () async {
    final service = _FakePluginLifecycleService();
    final response = await buildHandler(service: service).handleInternal(
      makeRequest(
        "POST",
        "/plugin/one/command",
        body: jsonEncode(const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe).toJson()),
      ),
      pathParams: const {"id": "one"},
      queryParams: const {},
      fragment: null,
    );

    expect(response.status, 200);
    expect(service.receivedPluginId, "one");
    expect(service.receivedRequest, const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe));
    expect(
      PluginManagementResponse.fromJson(jsonDecodeMap(response.body!)),
      _response,
    );
  });

  test("PostPluginLifecycleCommandHandler maps invalid, unknown, conflict, uncertain, and failed commands", () async {
    final service = _FakePluginLifecycleService();
    final handler = buildHandler(service: service);

    final invalid = await handler.handleInternal(
      makeRequest("POST", "/plugin/one/command", body: jsonEncode(const {"type": "disable"})),
      pathParams: const {"id": "one"},
      queryParams: const {},
      fragment: null,
    );
    service.error = const PluginManagementPluginNotFoundException("missing");
    final unknown = await _send(handler, pluginId: "missing");
    service.error = const PluginManagementConflictException(_conflict);
    final conflict = await _send(handler, pluginId: "one");
    service.error = const PluginManagementMutationOutcomeUncertainException();
    final uncertain = await _send(handler, pluginId: "one");
    service.error = const PluginManagementCommandFailedException("disk full");
    final failed = await _send(handler, pluginId: "one");

    expect(invalid.status, 400);
    expect(unknown.status, 404);
    expect(conflict.status, 409);
    expect(PluginLifecycleConflict.fromJson(jsonDecodeMap(conflict.body!)), _conflict);
    expect(uncertain.status, 503);
    expect(failed.status, 500);
    expect(failed.body, "plugin command failed");
  });
}

Future<RelayResponse> _send(PostPluginLifecycleCommandHandler handler, {required String pluginId}) {
  return handler.handleInternal(
    makeRequest(
      "POST",
      "/plugin/$pluginId/command",
      body: jsonEncode(const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.force).toJson()),
    ),
    pathParams: {"id": pluginId},
    queryParams: const {},
    fragment: null,
  );
}

const _plugin = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "one",
    displayName: "One",
    state: PluginSetupState.ready,
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.dormant,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 10,
  hasIdleTimeoutOverride: false,
  managementCapabilities: {
    PluginManagementCapability.lifecycle,
    PluginManagementCapability.setupRefresh,
    PluginManagementCapability.idleTimeout,
  },
  actionHint: null,
);

const _response = PluginManagementResponse(
  snapshotToken: "snapshot-token",
  bridgeId: "br_test1234",
  defaultPluginId: "one",
  defaultIdleTimeoutMins: 10,
  plugins: [_plugin],
);

const _conflict = PluginLifecycleConflict(
  pluginId: "one",
  reasons: [PluginLifecycleConflictReason.busy],
  current: _plugin,
);

class _FakePluginLifecycleService implements PluginLifecycleService {
  String? receivedPluginId;
  PluginLifecycleCommandRequest? receivedRequest;
  Object? error;

  @override
  Future<PluginManagementResponse> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) async {
    receivedPluginId = pluginId;
    receivedRequest = request;
    final currentError = error;
    if (currentError != null) throw currentError;
    return _response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

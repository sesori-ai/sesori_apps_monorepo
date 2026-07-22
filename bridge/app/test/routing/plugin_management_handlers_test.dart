import "dart:convert";

import "package:sesori_bridge/src/routing/get_plugin_management_handler.dart";
import "package:sesori_bridge/src/routing/patch_plugin_idle_timeout_handler.dart";
import "package:sesori_bridge/src/routing/post_plugin_lifecycle_command_handler.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";

void main() {
  test("GET /plugin/management returns the service snapshot", () async {
    final response =
        await GetPluginManagementHandler(
          lifecycleService: _FakePluginLifecycleService(),
        ).handleInternal(
          makeRequest("GET", "/plugin/management"),
          pathParams: const {},
          queryParams: const {},
          fragment: null,
        );

    expect(response.status, 200);
    expect(PluginManagementResponse.fromJson(jsonDecodeMap(response.body!)), _managementResponse);
  });

  test("command handler maps malformed, unknown, conflict, and mechanical failures", () async {
    final service = _FakePluginLifecycleService();
    final handler = PostPluginLifecycleCommandHandler(lifecycleService: service);

    final malformed = await handler.handleInternal(
      makeRequest("POST", "/plugin/one/command", body: jsonEncode(const {"type": "disable"})),
      pathParams: const {"id": "one"},
      queryParams: const {},
      fragment: null,
    );
    final unknown = await handler.handleInternal(
      makeRequest(
        "POST",
        "/plugin/missing/command",
        body: jsonEncode(const PluginLifecycleCommandRequest.enable().toJson()),
      ),
      pathParams: const {"id": "missing"},
      queryParams: const {},
      fragment: null,
    );
    final conflict = await handler.handleInternal(
      makeRequest(
        "POST",
        "/plugin/one/command",
        body: jsonEncode(
          const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe).toJson(),
        ),
      ),
      pathParams: const {"id": "one"},
      queryParams: const {},
      fragment: null,
    );
    service.mechanicalFailure = true;
    final mechanical = await handler.handleInternal(
      makeRequest(
        "POST",
        "/plugin/one/command",
        body: jsonEncode(const PluginLifecycleCommandRequest.enable().toJson()),
      ),
      pathParams: const {"id": "one"},
      queryParams: const {},
      fragment: null,
    );

    expect(malformed.status, 400);
    expect(unknown.status, 404);
    expect(conflict.status, 409);
    expect(conflict.headers["content-type"], "application/json");
    expect(
      PluginLifecycleConflict.fromJson(jsonDecodeMap(conflict.body!)).reasons,
      [PluginLifecycleConflictReason.busy],
    );
    expect(mechanical.status, 500);
  });

  test("idle timeout handler maps unknown plugins to 404", () async {
    final response =
        await PatchPluginIdleTimeoutHandler(
          lifecycleService: _FakePluginLifecycleService(),
        ).handleInternal(
          makeRequest(
            "PATCH",
            "/plugin/idle-timeout",
            body: jsonEncode(
              const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "missing").toJson(),
            ),
          ),
          pathParams: const {},
          queryParams: const {},
          fragment: null,
        );

    expect(response.status, 404);
  });

  test("idle timeout handler rejects fractional timeout fields", () async {
    final handler = PatchPluginIdleTimeoutHandler(
      lifecycleService: _FakePluginLifecycleService(),
    );

    for (final body in const [
      {"type": "applyAll", "idleTimeoutMins": 1.5},
      {"type": "setOverride", "pluginId": "one", "idleTimeoutMins": -2.5},
    ]) {
      final response = await handler.handleInternal(
        makeRequest("PATCH", "/plugin/idle-timeout", body: jsonEncode(body)),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.status, 400);
    }
  });
}

const _row = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "one",
    displayName: "One",
    state: PluginSetupState.ready,
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.idle,
  idleTimeoutMins: 10,
  hasIdleTimeoutOverride: false,
  actionHint: null,
);

const _managementResponse = PluginManagementResponse(
  revision: 2,
  defaultPluginId: "one",
  defaultIdleTimeoutMins: 10,
  plugins: [_row],
);

class _FakePluginLifecycleService implements PluginLifecycleService {
  bool mechanicalFailure = false;

  @override
  PluginManagementResponse get managementSnapshot => _managementResponse;

  @override
  Future<PluginManagementResponse> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) async {
    if (mechanicalFailure) throw StateError("mechanical failure");
    if (pluginId == "missing") throw const PluginManagementPluginNotFoundException("missing");
    if (request is PluginLifecycleDisableRequest) {
      throw const PluginManagementConflictException(
        PluginLifecycleConflict(
          pluginId: "one",
          reasons: [PluginLifecycleConflictReason.busy],
          current: _row,
        ),
      );
    }
    return _managementResponse;
  }

  @override
  Future<PluginManagementResponse> updateIdleTimeout({required PluginIdleTimeoutUpdateRequest request}) async {
    throw const PluginManagementPluginNotFoundException("missing");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

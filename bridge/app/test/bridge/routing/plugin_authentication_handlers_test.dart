import "package:sesori_bridge/src/routing/plugin_authentication_handlers.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  test("authentication handlers match only their exact methods and path", () {
    final service = _FakePluginLifecycleService();
    final start = PostPluginAuthenticationHandler(lifecycleService: service);
    final cancel = DeletePluginAuthenticationHandler(lifecycleService: service);

    expect(start.canHandle(makeRequest("POST", "/plugin/codex/authentication")), isTrue);
    expect(start.canHandle(makeRequest("DELETE", "/plugin/codex/authentication")), isFalse);
    expect(cancel.canHandle(makeRequest("DELETE", "/plugin/codex/authentication")), isTrue);
    expect(cancel.canHandle(makeRequest("POST", "/plugin/codex/authentication")), isFalse);
  });

  test("POST returns a typed challenge and DELETE cancels", () async {
    final service = _FakePluginLifecycleService();
    final request = makeRequest("POST", "/plugin/codex/authentication");
    final started = await PostPluginAuthenticationHandler(lifecycleService: service).handleInternal(
      request,
      pathParams: const {"id": "codex"},
      queryParams: const {},
      fragment: null,
    );
    final cancelled = await DeletePluginAuthenticationHandler(lifecycleService: service).handleInternal(
      makeRequest("DELETE", "/plugin/codex/authentication"),
      pathParams: const {"id": "codex"},
      queryParams: const {},
      fragment: null,
    );

    expect(started.status, 200);
    expect(
      PluginAuthenticationChallengeResponse.fromJson(jsonDecodeMap(started.body!)),
      const PluginAuthenticationChallengeResponse.deviceCode(
        verificationUrl: "https://auth.example/device",
        userCode: "ABCD-EFGH",
      ),
    );
    expect(cancelled.status, 200);
    expect(service.startedPluginId, "codex");
    expect(service.cancelledPluginId, "codex");
  });

  test("POST maps unknown plugins and typed conflicts", () async {
    final service = _FakePluginLifecycleService();
    final handler = PostPluginAuthenticationHandler(lifecycleService: service);
    service.error = const PluginManagementPluginNotFoundException("missing");
    final missing = await handler.handleInternal(
      makeRequest("POST", "/plugin/missing/authentication"),
      pathParams: const {"id": "missing"},
      queryParams: const {},
      fragment: null,
    );
    service.error = const PluginAuthenticationConflictException(_conflict);
    final conflict = await handler.handleInternal(
      makeRequest("POST", "/plugin/codex/authentication"),
      pathParams: const {"id": "codex"},
      queryParams: const {},
      fragment: null,
    );

    expect(missing.status, 404);
    expect(conflict.status, 409);
    expect(PluginAuthenticationConflict.fromJson(jsonDecodeMap(conflict.body!)), _conflict);
  });

  test("DELETE maps typed unsupported conflicts", () async {
    final service = _FakePluginLifecycleService()..cancelError = const PluginAuthenticationConflictException(_conflict);
    final response = await DeletePluginAuthenticationHandler(lifecycleService: service).handleInternal(
      makeRequest("DELETE", "/plugin/codex/authentication"),
      pathParams: const {"id": "codex"},
      queryParams: const {},
      fragment: null,
    );

    expect(response.status, 409);
    expect(PluginAuthenticationConflict.fromJson(jsonDecodeMap(response.body!)), _conflict);
  });
}

const _metadata = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "codex",
    displayName: "Codex",
    state: PluginSetupState.authenticationRequired,
    actionHint: "Sign in.",
  ),
  runtimeState: PluginRuntimeState.blocked,
  workState: PluginManagementWorkState.unknown,
  authenticationState: PluginAuthenticationState.idle,
  idleTimeoutMins: 0,
  hasIdleTimeoutOverride: false,
  managementCapabilities: {PluginManagementCapability.authentication},
  actionHint: "Sign in.",
);

const _conflict = PluginAuthenticationConflict(
  pluginId: "codex",
  reasons: [PluginAuthenticationConflictReason.inFlight],
  current: _metadata,
);

class _FakePluginLifecycleService() implements PluginLifecycleService {
  String? startedPluginId;
  String? cancelledPluginId;
  Object? error;
  Object? cancelError;

  @override
  Future<PluginAuthenticationChallengeResponse> authenticate({required String pluginId}) async {
    startedPluginId = pluginId;
    final currentError = error;
    if (currentError != null) throw currentError;
    return const PluginAuthenticationChallengeResponse.deviceCode(
      verificationUrl: "https://auth.example/device",
      userCode: "ABCD-EFGH",
    );
  }

  @override
  Future<SuccessEmptyResponse> cancelAuthentication({required String pluginId}) async {
    cancelledPluginId = pluginId;
    final currentError = cancelError;
    if (currentError != null) throw currentError;
    return const SuccessEmptyResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

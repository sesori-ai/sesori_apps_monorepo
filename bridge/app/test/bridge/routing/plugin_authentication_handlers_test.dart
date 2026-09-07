import "dart:convert";

import "package:sesori_bridge/src/routing/plugin_authentication_handlers.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  test("authentication handlers match only their exact methods and path", () {
    final service = _FakePluginLifecycleService();
    final start = PostPluginAuthenticationHandler(lifecycleService: service);
    final redirect = PostPluginAuthenticationRedirectHandler(lifecycleService: service);
    final cancel = DeletePluginAuthenticationHandler(lifecycleService: service);

    expect(start.canHandle(makeRequest("POST", "/plugin/codex/authentication")), isTrue);
    expect(start.canHandle(makeRequest("DELETE", "/plugin/codex/authentication")), isFalse);
    expect(redirect.canHandle(makeRequest("POST", "/plugin/codex/authentication/redirect")), isTrue);
    expect(cancel.canHandle(makeRequest("DELETE", "/plugin/codex/authentication")), isTrue);
    expect(cancel.canHandle(makeRequest("POST", "/plugin/codex/authentication")), isFalse);
  });

  test("POST returns a typed challenge and DELETE cancels", () async {
    final service = _FakePluginLifecycleService();
    final request = makeRequest("POST", "/plugin/codex/authentication");
    final started = await PostPluginAuthenticationHandler(lifecycleService: service).routeForTest(
      request,
    );
    final cancelled = await DeletePluginAuthenticationHandler(lifecycleService: service).routeForTest(
      makeRequest("DELETE", "/plugin/codex/authentication"),
    );

    expect(started.status, 200);
    expect(
      PluginAuthenticationChallengeResponse.fromJson(jsonDecodeMap(started.body!)).toJson(),
      const PluginAuthenticationChallengeResponse.deviceCode(
        verificationUrl: "https://auth.example/device",
        userCode: "ABCD-EFGH",
      ).toJson(),
    );
    expect(cancelled.status, 200);
    expect(service.startedPluginId, "codex");
    expect(service.cancelledPluginId, "codex");
  });

  test("POST maps unknown plugins and typed conflicts", () async {
    final service = _FakePluginLifecycleService();
    final handler = PostPluginAuthenticationHandler(lifecycleService: service);
    service.error = const PluginManagementPluginNotFoundException("missing");
    final missing = await handler.routeForTest(
      makeRequest("POST", "/plugin/missing/authentication"),
    );
    service.error = const PluginAuthenticationConflictException(_conflict);
    final conflict = await handler.routeForTest(
      makeRequest("POST", "/plugin/codex/authentication"),
    );

    expect(missing.status, 404);
    expect(conflict.status, 409);
    expect(PluginAuthenticationConflict.fromJson(jsonDecodeMap(conflict.body!)), _conflict);
  });

  test("redirect POST parses bounded URIs and maps typed failures", () async {
    final service = _FakePluginLifecycleService();
    final handler = PostPluginAuthenticationRedirectHandler(lifecycleService: service);
    const request = PluginAuthenticationRedirectRequest(
      redirectUrl: "http://127.0.0.1:43120/callback?code=opaque",
    );
    Future<RelayResponse> send() => handler.routeForTest(
      makeRequest("POST", "/plugin/codex/authentication/redirect", body: jsonEncode(request.toJson())),
    );
    final accepted = await send();
    expect(
      (accepted.status, service.redirectPluginId, service.submittedRedirect),
      (200, "codex", Uri.parse(request.redirectUrl)),
    );
    service.redirectError = const PluginAuthenticationContinuationConflictException(
      reason: PluginAuthenticationContinuationConflictReason.alreadySubmitted,
      conflict: _continuationConflict,
    );
    final conflict = await send();
    expect(conflict.status, 409);
    expect(PluginAuthenticationConflict.fromJson(jsonDecodeMap(conflict.body!)), _continuationConflict);
    final oversizedUrl = List.filled(PluginAuthenticationRedirectRequest.maxRedirectUrlLength + 1, "x").join();
    expect(
      (await handler.routeForTest(
        makeRequest("POST", "/plugin/codex/authentication/redirect", body: jsonEncode({"redirectUrl": oversizedUrl})),
      )).status,
      400,
    );
  });

  test("DELETE maps typed unsupported conflicts", () async {
    final service = _FakePluginLifecycleService()..cancelError = const PluginAuthenticationConflictException(_conflict);
    final response = await DeletePluginAuthenticationHandler(lifecycleService: service).routeForTest(
      makeRequest("DELETE", "/plugin/codex/authentication"),
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
    runtimeVersion: "0.42.0",
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

const _continuationConflict = PluginAuthenticationConflict(
  pluginId: "codex",
  reasons: [PluginAuthenticationConflictReason.alreadySubmitted],
  current: _metadata,
);

class _FakePluginLifecycleService() implements PluginLifecycleService {
  String? startedPluginId;
  String? cancelledPluginId;
  String? redirectPluginId;
  Uri? submittedRedirect;
  Object? error;
  Object? cancelError;
  Object? redirectError;

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
  Future<void> submitAuthenticationRedirect({required String pluginId, required Uri redirectUri}) async {
    redirectPluginId = pluginId;
    submittedRedirect = redirectUri;
    final currentError = redirectError;
    if (currentError != null) throw currentError;
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

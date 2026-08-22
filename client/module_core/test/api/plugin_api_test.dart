import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/plugin_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "../helpers/test_helpers.dart";

void main() {
  late MockRelayHttpApiClient client;
  late PluginApi api;

  setUp(() {
    client = MockRelayHttpApiClient();
    api = PluginApi(client: client);
  });

  test("GET /plugin parses metadata and preserves bridge order", () async {
    when(
      () => client.get<PluginListResponse>("/plugin", fromJson: any(named: "fromJson")),
    ).thenAnswer((invocation) async {
      final fromJson = invocation.namedArguments[#fromJson] as PluginListResponse Function(Map<String, dynamic>);
      return ApiResponse.success(
        fromJson({
          "plugins": [
            {
              "id": "plugin-b",
              "displayName": "Plugin B",
              "isDefault": false,
              "state": "degraded",
              "actionHint": "Check the bridge console.",
            },
            {
              "id": "plugin-a",
              "displayName": "Plugin A",
              "isDefault": true,
              "state": "ready",
              "actionHint": null,
            },
          ],
        }),
      );
    });

    final response = await api.listPlugins();

    final data = (response as SuccessResponse<PluginListResponse>).data;
    expect(data.plugins.map((plugin) => plugin.id), ["plugin-b", "plugin-a"]);
    expect(data.plugins.first.state, PluginLifecycleState.degraded);
    expect(data.plugins.first.actionHint, "Check the bridge console.");
    expect(data.plugins.last.isDefault, isTrue);
    verify(
      () => client.get<PluginListResponse>("/plugin", fromJson: any(named: "fromJson")),
    ).called(1);
  });

  test("GET /plugin surfaces discovery errors", () async {
    final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null);
    when(
      () => client.get<PluginListResponse>("/plugin", fromJson: any(named: "fromJson")),
    ).thenAnswer((_) async => ApiResponse.error(error));

    expect(await api.listPlugins(), ApiResponse<PluginListResponse>.error(error));
  });

  test("GET /plugin/management parses the typed snapshot", () async {
    when(
      () => client.get<PluginManagementResponse>("/plugin/management", fromJson: any(named: "fromJson")),
    ).thenAnswer((invocation) async {
      final fromJson = invocation.namedArguments[#fromJson] as PluginManagementResponse Function(Map<String, dynamic>);
      return ApiResponse.success(fromJson(_managementJson));
    });

    final response = await api.getManagement();

    final data = (response as SuccessResponse<PluginManagementResponse>).data;
    expect(data.bridgeId, "br_abc12345");
    expect(data.snapshotToken, "snapshot-token");
    expect(data.plugins.single.setup.id, "opencode");
    verify(
      () => client.get<PluginManagementResponse>("/plugin/management", fromJson: any(named: "fromJson")),
    ).called(1);
  });

  test("POST /plugin/:id/command serializes the shared request model", () async {
    when(
      () => client.post<PluginManagementResponse>(
        any(),
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((invocation) async {
      final fromJson = invocation.namedArguments[#fromJson] as PluginManagementResponse Function(Map<String, dynamic>);
      return ApiResponse.success(fromJson(_managementJson));
    });

    final response = await api.command(
      pluginId: "codex",
      request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
    );

    expect(response, isA<SuccessResponse<PluginManagementResponse>>());
    final captured = verify(
      () => client.post<PluginManagementResponse>(
        captureAny(),
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured;
    expect(captured[0], "/plugin/codex/command");
    expect(captured[1], const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe).toJson());
  });

  test("PATCH /plugin/idle-timeout serializes the shared request model", () async {
    when(
      () => client.patch<PluginManagementResponse>(
        any(),
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((invocation) async {
      final fromJson = invocation.namedArguments[#fromJson] as PluginManagementResponse Function(Map<String, dynamic>);
      return ApiResponse.success(fromJson(_managementJson));
    });

    final response = await api.updateIdleTimeout(
      request: const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "codex", idleTimeoutMins: 45),
    );

    expect(response, isA<SuccessResponse<PluginManagementResponse>>());
    final captured = verify(
      () => client.patch<PluginManagementResponse>(
        captureAny(),
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured;
    expect(captured[0], "/plugin/idle-timeout");
    expect(
      captured[1],
      const PluginIdleTimeoutUpdateRequest.setOverride(pluginId: "codex", idleTimeoutMins: 45).toJson(),
    );
  });

  test("POST and DELETE /plugin/:id/authentication use typed models", () async {
    when(
      () => client.post<PluginAuthenticationChallengeResponse>(
        any(),
        body: any(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).thenAnswer((invocation) async {
      final fromJson =
          invocation.namedArguments[#fromJson] as PluginAuthenticationChallengeResponse Function(Map<String, dynamic>);
      return ApiResponse.success(
        fromJson({
          "type": "deviceCode",
          "verificationUrl": "https://auth.example/device",
          "userCode": "ABCD-EFGH",
        }),
      );
    });
    when(
      () => client.delete<SuccessEmptyResponse>(any(), fromJson: any(named: "fromJson")),
    ).thenAnswer((_) async => ApiResponse.success(const SuccessEmptyResponse()));

    final started = await api.startAuthentication(pluginId: "codex/dev");
    final cancelled = await api.cancelAuthentication(pluginId: "codex/dev");

    expect(started, isA<SuccessResponse<PluginAuthenticationChallengeResponse>>());
    expect(cancelled, isA<SuccessResponse<SuccessEmptyResponse>>());
    final start = verify(
      () => client.post<PluginAuthenticationChallengeResponse>(
        captureAny(),
        body: captureAny(named: "body"),
        fromJson: any(named: "fromJson"),
      ),
    ).captured;
    expect(start[0], "/plugin/codex%2Fdev/authentication");
    expect(start[1], const SuccessEmptyResponse().toJson());
    verify(
      () => client.delete<SuccessEmptyResponse>(
        "/plugin/codex%2Fdev/authentication",
        fromJson: any(named: "fromJson"),
      ),
    ).called(1);
  });
}

const _managementJson = {
  "snapshotToken": "snapshot-token",
  "bridgeId": "br_abc12345",
  "defaultPluginId": "opencode",
  "defaultIdleTimeoutMins": 30,
  "plugins": [
    {
      "setup": {"id": "opencode", "displayName": "OpenCode", "state": "ready", "actionHint": null},
      "runtimeState": "active",
      "workState": "idle",
      "idleTimeoutMins": 30,
      "hasIdleTimeoutOverride": false,
      "managementCapabilities": ["lifecycle", "setupRefresh", "idleTimeout"],
    },
  ],
};

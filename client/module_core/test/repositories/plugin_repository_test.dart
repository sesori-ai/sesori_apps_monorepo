import "dart:async";
import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/plugin_api.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockPluginApi extends Mock implements PluginApi {}

void main() {
  late MockPluginApi api;
  late PluginRepository repository;

  setUpAll(() {
    registerFallbackValue(const PluginLifecycleCommandRequest.enable());
    registerFallbackValue(const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 0));
  });

  setUp(() {
    api = MockPluginApi();
    repository = PluginRepository(api: api);
  });

  test("returns the backend-neutral plugin response unchanged", () async {
    const response = PluginListResponse(
      bridgeId: "br_abc12345",
      plugins: [
        PluginMetadata(
          id: "plugin-b",
          displayName: "Plugin B",
          isDefault: false,
          state: PluginLifecycleState.failed,
          actionHint: "Restart the bridge.",
        ),
        PluginMetadata(
          id: "plugin-a",
          displayName: "Plugin A",
          isDefault: true,
          state: PluginLifecycleState.ready,
          actionHint: null,
        ),
      ],
    );
    when(api.listPlugins).thenAnswer((_) async => ApiResponse.success(response));

    expect(await repository.listPlugins(), ApiResponse<PluginListResponse>.success(response));
  });

  test("maps an unsupported discovery route to the legacy OpenCode plugin", () async {
    when(api.listPlugins).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );

    expect(
      await repository.listPlugins(),
      ApiResponse<PluginListResponse>.success(
        const PluginListResponse(
          bridgeId: null,
          plugins: [
            PluginMetadata(
              id: legacyMissingPluginId,
              displayName: "OpenCode",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
          ],
        ),
      ),
    );
  });

  test("surfaces errors other than an unsupported discovery route", () async {
    final error = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null);
    when(api.listPlugins).thenAnswer((_) async => ApiResponse.error(error));

    expect(await repository.listPlugins(), ApiResponse<PluginListResponse>.error(error));
  });

  group("getManagement", () {
    test("maps a typed snapshot to supported", () async {
      when(api.getManagement).thenAnswer((_) async => ApiResponse.success(_managementResponse));

      final result = await repository.getManagement();

      expect(
        result,
        isA<PluginManagementLoadResultSupported>()
            .having((r) => r.response, "response", _managementResponse)
            .having((r) => r.refreshError, "refreshError", isNull),
      );
    });

    test("maps an unknown management route to unsupported", () async {
      when(api.getManagement).thenAnswer(
        (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
      );

      expect(await repository.getManagement(), isA<PluginManagementLoadResultUnsupported>());
    });

    test("maps other errors to explicit failure", () async {
      final error = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null);
      when(api.getManagement).thenAnswer((_) async => ApiResponse.error(error));

      expect(
        await repository.getManagement(),
        isA<PluginManagementLoadResultFailure>().having((r) => r.error, "error", error),
      );
    });
  });

  group("mutations", () {
    test("maps a typed success body", () async {
      when(
        () => api.command(
          pluginId: any(named: "pluginId"),
          request: any(named: "request"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(_managementResponse));

      final result = await repository.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.enable(),
      );

      expect(
        result,
        isA<PluginManagementMutationResultSuccess>().having((r) => r.response, "response", _managementResponse),
      );
    });

    test("maps an unknown plugin to notFound", () async {
      when(
        () => api.updateIdleTimeout(request: any(named: "request")),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));

      final result = await repository.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30),
      );

      expect(result, isA<PluginManagementMutationResultNotFound>());
    });

    test("parses a typed conflict", () async {
      when(
        () => api.command(
          pluginId: any(named: "pluginId"),
          request: any(named: "request"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(errorCode: 409, rawErrorString: jsonEncode(_conflictJson)),
        ),
      );

      final result = await repository.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe),
      );

      expect(
        result,
        isA<PluginManagementMutationResultConflict>().having((r) => r.conflict.pluginId, "pluginId", "codex").having(
          (r) => r.conflict.reasons,
          "reasons",
          [PluginLifecycleConflictReason.busy],
        ),
      );
    });

    test("maps a malformed conflict body to explicit failure", () async {
      final error = ApiError.nonSuccessCode(errorCode: 409, rawErrorString: "not json");
      when(
        () => api.command(
          pluginId: any(named: "pluginId"),
          request: any(named: "request"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final result = await repository.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      );

      expect(
        result,
        isA<PluginManagementMutationResultFailure>().having((r) => r.error, "error", error),
      );
    });

    test("maps an undecodable successful mutation body to uncertain", () async {
      when(
        () => api.command(
          pluginId: any(named: "pluginId"),
          request: any(named: "request"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.jsonParsing("garbage")));

      final result = await repository.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.refresh(),
      );

      expect(result, isA<PluginManagementMutationResultUncertain>());
    });

    test("maps an empty successful mutation body to uncertain", () async {
      when(
        () => api.updateIdleTimeout(request: any(named: "request")),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.emptyResponse()));

      final result = await repository.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "codex"),
      );

      expect(result, isA<PluginManagementMutationResultUncertain>());
    });

    test("maps a post-dispatch response loss to uncertain", () async {
      when(
        () => api.command(
          pluginId: any(named: "pluginId"),
          request: any(named: "request"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.dartHttpClient(TimeoutException("Relay request timed out", const Duration(seconds: 30))),
        ),
      );

      final result = await repository.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      );

      expect(result, isA<PluginManagementMutationResultUncertain>());
    });

    test("maps a socket-close response loss to uncertain", () async {
      when(
        () => api.command(
          pluginId: any(named: "pluginId"),
          request: any(named: "request"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.dartHttpClient(const RelayResponseLostException(message: "Relay socket closed (code=1001)")),
        ),
      );

      final result = await repository.command(
        pluginId: "codex",
        request: const PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe),
      );

      expect(result, isA<PluginManagementMutationResultUncertain>());
    });

    test("maps generic mutation errors to explicit failure", () async {
      final error = ApiError.generic();
      when(
        () => api.updateIdleTimeout(request: any(named: "request")),
      ).thenAnswer((_) async => ApiResponse.error(error));

      final result = await repository.updateIdleTimeout(
        request: const PluginIdleTimeoutUpdateRequest.applyAll(idleTimeoutMins: 30),
      );

      expect(
        result,
        isA<PluginManagementMutationResultFailure>().having((r) => r.error, "error", error),
      );
    });
  });
}

const _managementPlugin = PluginManagementMetadata(
  setup: PluginSetupMetadata(
    id: "codex",
    displayName: "Codex",
    state: PluginSetupState.ready,
    actionHint: null,
  ),
  runtimeState: PluginRuntimeState.active,
  workState: PluginManagementWorkState.busy,
  idleTimeoutMins: 30,
  hasIdleTimeoutOverride: false,
  actionHint: null,
);

const _managementResponse = PluginManagementResponse(
  snapshotToken: "snapshot-token",
  bridgeId: "br_abc12345",
  defaultPluginId: "codex",
  defaultIdleTimeoutMins: 30,
  plugins: [_managementPlugin],
);

const _conflictJson = {
  "pluginId": "codex",
  "reasons": ["busy"],
  "current": {
    "setup": {"id": "codex", "displayName": "Codex", "state": "ready", "actionHint": null},
    "runtimeState": "active",
    "workState": "busy",
    "idleTimeoutMins": 30,
    "hasIdleTimeoutOverride": false,
  },
};

import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/plugin_api.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_management_result.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_management_test_data.dart";

class MockPluginApi extends Mock implements PluginApi {}

void main() {
  late MockPluginApi api;
  late PluginRepository repository;

  setUp(() {
    api = MockPluginApi();
    repository = PluginRepository(api: api);
  });

  test("returns the backend-neutral plugin response unchanged", () async {
    const response = PluginListResponse(
      bridgeId: "bridge-1",
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

  test("maps management 404 to typed unsupported", () async {
    when(api.getManagement).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );

    expect(await repository.getManagement(), const PluginManagementLoadResult.unsupported());
  });

  test("maps management success and other failures explicitly", () async {
    when(api.getManagement).thenAnswer(
      (_) async => ApiResponse.success(testPluginManagementResponse),
    );
    expect(
      await repository.getManagement(),
      const PluginManagementLoadResult.supported(response: testPluginManagementResponse),
    );

    final error = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: "unavailable");
    when(api.getManagement).thenAnswer((_) async => ApiResponse.error(error));
    expect(await repository.getManagement(), PluginManagementLoadResult.failure(error: error));
  });

  test("maps command 404 to typed not-found", () async {
    const request = PluginLifecycleCommandRequest.refresh();
    when(() => api.command(pluginId: "missing", request: request)).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );

    expect(
      await repository.command(pluginId: "missing", request: request),
      const PluginManagementMutationResult.notFound(),
    );
  });

  test("parses a valid command 409 as a typed lifecycle conflict", () async {
    const request = PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe);
    const conflict = PluginLifecycleConflict(
      pluginId: "plugin-a",
      reasons: [PluginLifecycleConflictReason.busy],
      current: testPluginA,
    );
    when(() => api.command(pluginId: "plugin-a", request: request)).thenAnswer(
      (_) async => ApiResponse.error(
        ApiError.nonSuccessCode(errorCode: 409, rawErrorString: jsonEncode(conflict.toJson())),
      ),
    );

    expect(
      await repository.command(pluginId: "plugin-a", request: request),
      const PluginManagementMutationResult.conflict(conflict: conflict),
    );
  });

  test("keeps malformed command 409 and other errors explicit", () async {
    const request = PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe);
    final malformed = ApiError.nonSuccessCode(errorCode: 409, rawErrorString: "not-json");
    when(
      () => api.command(pluginId: "plugin-a", request: request),
    ).thenAnswer((_) async => ApiResponse.error(malformed));
    expect(
      await repository.command(pluginId: "plugin-a", request: request),
      PluginManagementMutationResult.failure(error: malformed),
    );

    final failure = ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "failed");
    when(
      () => api.command(pluginId: "plugin-a", request: request),
    ).thenAnswer((_) async => ApiResponse.error(failure));
    expect(
      await repository.command(pluginId: "plugin-a", request: request),
      PluginManagementMutationResult.failure(error: failure),
    );
  });

  test("maps idle-timeout mutation results through the same typed boundary", () async {
    const request = PluginIdleTimeoutUpdateRequest.clearOverride(pluginId: "plugin-a");
    when(
      () => api.updateIdleTimeout(request: request),
    ).thenAnswer((_) async => ApiResponse.success(testPluginManagementResponse));

    expect(
      await repository.updateIdleTimeout(request: request),
      const PluginManagementMutationResult.success(response: testPluginManagementResponse),
    );
  });
}

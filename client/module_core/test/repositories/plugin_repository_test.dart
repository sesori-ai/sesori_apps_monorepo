import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/plugin_api.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockPluginApi extends Mock implements PluginApi {}

void main() {
  late MockPluginApi api;
  late PluginRepository repository;

  setUp(() {
    api = MockPluginApi();
    repository = PluginRepository(api: api);
  });

  test("temporary release gate exposes only OpenCode and makes it the default", () async {
    const response = PluginListResponse(
      plugins: [
        PluginMetadata(
          id: "codex",
          displayName: "Codex",
          isDefault: true,
          state: PluginLifecycleState.ready,
          actionHint: null,
        ),
        PluginMetadata(
          id: legacyMissingPluginId,
          displayName: "OpenCode",
          isDefault: false,
          state: PluginLifecycleState.ready,
          actionHint: null,
        ),
      ],
    );
    when(api.listPlugins).thenAnswer((_) async => ApiResponse.success(response));

    expect(
      await repository.listPlugins(),
      ApiResponse<PluginListResponse>.success(
        const PluginListResponse(
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

  test("temporary release gate returns no choice when OpenCode is absent", () async {
    when(api.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        const PluginListResponse(
          plugins: [
            PluginMetadata(
              id: "codex",
              displayName: "Codex",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
          ],
        ),
      ),
    );

    expect(
      await repository.listPlugins(),
      ApiResponse<PluginListResponse>.success(
        const PluginListResponse(plugins: []),
      ),
    );
  });

  test("maps an unsupported discovery route to the legacy OpenCode plugin", () async {
    when(api.listPlugins).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );

    expect(
      await repository.listPlugins(),
      ApiResponse<PluginListResponse>.success(
        const PluginListResponse(
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
}

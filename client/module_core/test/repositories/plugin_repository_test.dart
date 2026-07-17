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

  test("returns the backend-neutral plugin response unchanged", () async {
    const response = PluginListResponse(
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

  test("surfaces API errors", () async {
    final error = ApiError.generic();
    when(api.listPlugins).thenAnswer((_) async => ApiResponse.error(error));

    expect(await repository.listPlugins(), ApiResponse<PluginListResponse>.error(error));
  });
}

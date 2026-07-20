import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/plugin_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

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
}

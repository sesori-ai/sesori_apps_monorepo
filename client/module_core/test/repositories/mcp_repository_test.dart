import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/mcp_api.dart";
import "package:sesori_dart_core/src/repositories/mcp_repository.dart";
import "package:sesori_dart_core/src/repositories/models/mcp_action_response.dart";
import "package:sesori_dart_core/src/repositories/models/mcp_read_result.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const request = McpInventoryRequest(pluginId: "fixture", scope: McpHarnessScope());
  late _Api api;
  late McpRepository repository;
  setUp(() {
    api = _Api();
    repository = McpRepository(api: api);
  });

  test("actions retain native unknown/busy outcomes and original transport causes", () async {
    const action = McpEntryActionRequest(
      pluginId: "fixture",
      action: McpForgetAuthenticationEntryAction(
        target: McpServerTarget(scope: McpHarnessScope(), serverKey: "fixture"),
      ),
    );
    for (final result in [
      const McpActionUnknown(),
      const McpActionUnavailable(reason: McpActionUnavailableReason.busy),
    ]) {
      api.actionResponse = SuccessResponse(result);
      expect((await repository.executeAction(request: action) as McpActionReceived).result, same(result));
    }
    final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "Missing route");
    api.actionResponse = ErrorResponse(error);
    expect((await repository.executeAction(request: action) as McpActionRequestFailed).cause, same(error));
  });

  test("native read failures stay distinct from scope and integration unavailability", () async {
    const failed = McpInventoryUnavailable(
      scope: McpHarnessScope(),
      reason: McpInventoryUnavailableReason.readFailed,
      message: "Retry",
    );
    api.response = SuccessResponse(failed);
    final failure = await repository.getInventory(request: request);
    expect((failure as McpReadInventoryFailed).cause, same(failed));
    const unavailable = McpInventoryUnavailable(
      scope: McpHarnessScope(),
      reason: McpInventoryUnavailableReason.unsupportedScope,
      message: "Open a session",
    );
    api.response = SuccessResponse(unavailable);
    expect((await repository.getInventory(request: request) as McpReadSuccess).inventory, same(unavailable));
  });

  test("404 preserves missing-route or missing-entity evidence without assuming bridge age", () async {
    for (final message in ["route not found", "session not found"]) {
      final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: message);
      api.response = ErrorResponse(error);
      expect((await repository.getInventory(request: request) as McpReadNotFound).cause, same(error));
    }
  });

  test("an unrecognized wire result stays distinct from a successful inventory", () async {
    api.response = SuccessResponse(McpInventoryResult.fromJson({"type": "future-result"}));
    expect(await repository.getInventory(request: request), isA<McpReadUnrecognized>());
  });

  test("authorization and transport failures preserve their original typed error", () async {
    final error = ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "Not authorized");
    api.response = ErrorResponse(error);
    expect((await repository.getInventory(request: request) as McpReadFailed).cause, same(error));
  });
}

class _Api() implements McpApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
  ApiResponse<McpInventoryResult> response = SuccessResponse(const McpInventoryUnknown());
  ApiResponse<McpEntryActionResult> actionResponse = SuccessResponse(const McpActionUnknown());
  @override
  Future<ApiResponse<McpEntryActionResult>> executeAction({required McpEntryActionRequest request}) async =>
      actionResponse;
  @override
  Future<ApiResponse<McpInventoryResult>> getInventory({required McpInventoryRequest request}) async => response;
}

import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/mcp_api.dart";
import "package:sesori_dart_core/src/repositories/mcp_repository.dart";
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

  test("authorization and transport failures preserve their original typed error", () async {
    final error = ApiError.nonSuccessCode(errorCode: 403, rawErrorString: "Not authorized");
    api.response = ErrorResponse(error);
    expect((await repository.getInventory(request: request) as McpReadFailed).cause, same(error));
  });
}

class _Api() implements McpApi {
  ApiResponse<McpInventoryResult> response = SuccessResponse(const McpInventoryUnknown());
  @override
  Future<ApiResponse<McpInventoryResult>> getInventory({required McpInventoryRequest request}) async => response;
}

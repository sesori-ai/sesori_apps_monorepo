import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class McpApi({required final RelayHttpApiClient _client}) {
  Future<ApiResponse<McpEntryActionResult>> executeAction({required McpEntryActionRequest request}) =>
      _client.postWithTimeout(
        "/mcp/entry/action",
        body: request.toJson(),
        fromJson: McpEntryActionResult.fromJson,
        // Native management and its subsequent discovery need a longer bounded budget.
        timeout: const Duration(minutes: 3, seconds: 30),
      );

  Future<ApiResponse<McpAuthenticationResult>> getAuthentication() => _client.get(
    "/mcp/authentication",
    fromJson: McpAuthenticationResult.fromJson,
  );

  Future<ApiResponse<McpAuthenticationResult>> startAuthentication({required McpAuthenticationStartRequest request}) =>
      _client.post("/mcp/authentication", body: request.toJson(), fromJson: McpAuthenticationResult.fromJson);

  Future<ApiResponse<McpAuthenticationResult>> continueAuthentication({
    required McpAuthenticationContinueRequest request,
  }) => _client.post(
    "/mcp/authentication/continue",
    body: request.toJson(),
    fromJson: McpAuthenticationResult.fromJson,
  );

  Future<ApiResponse<McpAuthenticationResult>> cancelAuthentication({
    required McpAuthenticationCancelRequest request,
  }) => _client.post("/mcp/authentication/cancel", body: request.toJson(), fromJson: McpAuthenticationResult.fromJson);

  Future<ApiResponse<McpInventoryResult>> getInventory({required McpInventoryRequest request}) => _client.post(
    "/mcp/inventory",
    body: request.toJson(),
    fromJson: McpInventoryResult.fromJson,
  );
}

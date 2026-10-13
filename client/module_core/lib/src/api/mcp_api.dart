import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class McpApi({required final RelayHttpApiClient _client}) {
  Future<ApiResponse<McpInventoryResult>> getInventory({required McpInventoryRequest request}) => _client.post(
    "/mcp/inventory",
    body: request.toJson(),
    fromJson: McpInventoryResult.fromJson,
  );
}

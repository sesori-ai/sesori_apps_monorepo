import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/mcp_api.dart";
import "models/mcp_read_result.dart";

@lazySingleton
class McpRepository({required final McpApi _api}) {
  Future<McpReadResult> getInventory({required McpInventoryRequest request}) async =>
      switch (await _api.getInventory(request: request)) {
        SuccessResponse(:final McpInventoryUnavailable data)
            when data.reason == McpInventoryUnavailableReason.readFailed =>
          McpReadInventoryFailed(cause: data),
        SuccessResponse(:final data) => McpReadSuccess(inventory: data),
        ErrorResponse(:final NonSuccessCodeError error) when error.errorCode == 404 => McpReadNotFound(cause: error),
        ErrorResponse(:final error) => McpReadFailed(cause: error),
      };
}

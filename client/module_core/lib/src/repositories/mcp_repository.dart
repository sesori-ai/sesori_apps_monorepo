import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/mcp_api.dart";
import "models/mcp_action_response.dart";
import "models/mcp_authentication_response.dart";
import "models/mcp_read_result.dart";
import "models/plugin_management_result.dart";

@lazySingleton
class McpRepository({required final McpApi _api}) {
  Future<McpActionResponse> executeAction({required McpEntryActionRequest request}) async =>
      switch (await _api.executeAction(request: request)) {
        SuccessResponse(:final data) => McpActionReceived(result: data),
        ErrorResponse(:final error) => McpActionRequestFailed(cause: error),
      };

  /// Setup destinations are short-lived response data, never saved in inventory.
  Uri? connectorSetupDestination({required McpExternalSetup result}) {
    final uri = Uri.tryParse(result.setupUrl);
    return uri != null && uri.scheme == "https" && uri.hasAuthority && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? uri
        : null;
  }

  Future<McpAuthenticationResponse> getAuthentication() => _authenticationResponse(response: _api.getAuthentication());

  Future<McpAuthenticationResponse> startAuthentication({required McpAuthenticationStartRequest request}) =>
      _authenticationResponse(response: _api.startAuthentication(request: request));

  Future<McpAuthenticationResponse> continueAuthentication({required McpAuthenticationContinueRequest request}) =>
      _authenticationResponse(response: _api.continueAuthentication(request: request));

  Future<McpAuthenticationResponse> cancelAuthentication({required McpAuthenticationCancelRequest request}) =>
      _authenticationResponse(response: _api.cancelAuthentication(request: request));

  Future<McpAuthenticationResponse> _authenticationResponse({
    required Future<ApiResponse<McpAuthenticationResult>> response,
  }) async => switch (await response) {
    SuccessResponse(:final data) => McpAuthenticationReceived(result: data),
    ErrorResponse(:final NonSuccessCodeError error) when error.errorCode == 404 => McpAuthenticationRouteMissing(
      cause: error,
    ),
    ErrorResponse(:final error) => McpAuthenticationRequestFailed(cause: error),
  };

  /// Parse destinations at the repository boundary before platform browser use.
  PluginAuthenticationBrowserChallenge? browserChallenge({required McpAuthenticationCallbackChallenge state}) {
    final authorization = Uri.tryParse(state.authorizationUrl);
    final callback = Uri.tryParse(state.expectedCallbackUrl);
    if (authorization == null ||
        !authorization.isAbsolute ||
        authorization.scheme != "https" ||
        authorization.host.isEmpty ||
        authorization.userInfo.isNotEmpty ||
        callback == null ||
        callback.scheme != "http" ||
        !const {"127.0.0.1", "localhost", "::1"}.contains(callback.host) ||
        callback.port <= 0 ||
        callback.userInfo.isNotEmpty ||
        callback.fragment.isNotEmpty) {
      return null;
    }
    return PluginAuthenticationBrowserChallenge(authorizationUri: authorization, expectedCallbackUri: callback);
  }

  Future<McpReadResult> getInventory({required McpInventoryRequest request}) async =>
      switch (await _api.getInventory(request: request)) {
        SuccessResponse(data: McpInventoryUnknown()) => const McpReadUnrecognized(),
        SuccessResponse(:final McpInventoryUnavailable data)
            when data.reason == McpInventoryUnavailableReason.readFailed =>
          McpReadInventoryFailed(cause: data),
        SuccessResponse(:final data) => McpReadSuccess(inventory: data),
        ErrorResponse(:final NonSuccessCodeError error) when error.errorCode == 404 => McpReadNotFound(cause: error),
        ErrorResponse(:final error) => McpReadFailed(cause: error),
      };
}

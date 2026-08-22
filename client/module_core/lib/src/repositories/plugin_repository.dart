import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/plugin_api.dart";
import "../capabilities/relay/relay_client.dart";
import "models/plugin_discovery_snapshot.dart";
import "models/plugin_management_result.dart";

@lazySingleton
class PluginRepository({required final PluginApi _api}) {
  Future<PluginManagementLoadResult> getManagement() async {
    return switch (await _api.getManagement()) {
      SuccessResponse(:final data) => PluginManagementLoadResult.supported(response: data, refreshError: null),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const PluginManagementLoadResult.unsupported(),
      ErrorResponse(:final error) => PluginManagementLoadResult.failure(error: error),
    };
  }

  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) {
    return _mapMutation(
      future: _api.command(pluginId: pluginId, request: request),
    );
  }

  Future<PluginManagementMutationResult> updateIdleTimeout({required PluginIdleTimeoutUpdateRequest request}) {
    return _mapMutation(future: _api.updateIdleTimeout(request: request));
  }

  Future<PluginAuthenticationStartResult> startAuthentication({required String pluginId}) async {
    return switch (await _api.startAuthentication(pluginId: pluginId)) {
      SuccessResponse(:final data) => PluginAuthenticationStartResult.challenge(challenge: data),
      ErrorResponse(:final error) => PluginAuthenticationStartResult.failed(
        failure: _mapAuthenticationFailure(error: error),
      ),
    };
  }

  Future<PluginAuthenticationCancelResult> cancelAuthentication({required String pluginId}) async {
    return switch (await _api.cancelAuthentication(pluginId: pluginId)) {
      SuccessResponse() => const PluginAuthenticationCancelResult.success(),
      ErrorResponse(:final error) => PluginAuthenticationCancelResult.failed(
        failure: _mapAuthenticationFailure(error: error),
      ),
    };
  }

  /// Start and cancel classify their errors identically, so both route through
  /// this one mapper.
  PluginAuthenticationFailure _mapAuthenticationFailure({required ApiError error}) {
    return switch (error) {
      NonSuccessCodeError(errorCode: 404) => const PluginAuthenticationFailure.notFound(),
      NonSuccessCodeError(errorCode: 409, rawErrorString: final body) => _mapAuthenticationConflict(body: body),
      // A malformed or empty body, and a timed-out or lost relay response, all
      // leave the bridge's actual state unknown.
      JsonParsingError() || EmptyResponseError() => const PluginAuthenticationFailure.uncertain(),
      DartHttpClientError(innerError: TimeoutException() || RelayResponseLostException()) =>
        const PluginAuthenticationFailure.uncertain(),
      NonSuccessCodeError() || DartHttpClientError() || GenericError() || NotAuthenticatedError() =>
        PluginAuthenticationFailure.request(error: error),
    };
  }

  PluginAuthenticationFailure _mapAuthenticationConflict({required String? body}) {
    return switch (_parseAuthenticationConflict(body: body)) {
      _AuthenticationConflictParsed(:final conflict) =>
        conflict.reasons.contains(PluginAuthenticationConflictReason.unsupported)
            ? const PluginAuthenticationFailure.unsupported()
            : PluginAuthenticationFailure.conflict(conflict: conflict),
      _AuthenticationConflictParseFailure(:final error) => PluginAuthenticationFailure.request(error: error),
    };
  }

  _AuthenticationConflictParseResult _parseAuthenticationConflict({required String? body}) {
    if (body == null) {
      return _AuthenticationConflictParseFailure(
        error: ApiError.nonSuccessCode(errorCode: 409, rawErrorString: null),
      );
    }
    try {
      return _AuthenticationConflictParsed(
        conflict: PluginAuthenticationConflict.fromJson(jsonDecodeMap(body)),
      );
    } on Object {
      return _AuthenticationConflictParseFailure(error: ApiError.jsonParsing(body));
    }
  }

  Future<PluginManagementMutationResult> _mapMutation({
    required Future<ApiResponse<PluginManagementResponse>> future,
  }) async {
    return switch (await future) {
      SuccessResponse(:final data) => PluginManagementMutationResult.success(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const PluginManagementMutationResult.notFound(),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 409, rawErrorString: final body)) => _mapConflict(body: body),
      // Management handlers use 503 when a mutation committed but its identity
      // fence moved before they could publish an authoritative response.
      ErrorResponse(error: NonSuccessCodeError(errorCode: 503)) => const PluginManagementMutationResult.uncertain(),
      // A sent mutation whose outcome cannot be proven may have committed;
      // never surface it as a retryable ordinary failure. This covers an
      // undecodable or empty 2xx body and a post-dispatch response loss.
      ErrorResponse(
        error: JsonParsingError() ||
            EmptyResponseError() ||
            DartHttpClientError(innerError: TimeoutException() || RelayResponseLostException()),
      ) =>
        const PluginManagementMutationResult.uncertain(),
      ErrorResponse(:final error) => PluginManagementMutationResult.failure(error: error),
    };
  }

  PluginManagementMutationResult _mapConflict({required String? body}) {
    if (body != null) {
      try {
        return PluginManagementMutationResult.conflict(
          conflict: PluginLifecycleConflict.fromJson(jsonDecodeMap(body)),
        );
      } on Object {
        // The typed failure below is the single observable outcome.
      }
    }
    return PluginManagementMutationResult.failure(
      error: ApiError.nonSuccessCode(errorCode: 409, rawErrorString: body),
    );
  }

  Future<ApiResponse<PluginDiscoverySnapshot>> listPlugins() async {
    final response = await _api.listPlugins();
    return switch (response) {
      SuccessResponse(:final data) => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: data.bridgeId,
          supportsSessionOptions: data.supportsSessionOptions,
          // COMPATIBILITY 2026-08-04 (v1.8.0): Discovery responses that omit
          // session-options capability also predate prompt capability, while
          // their sole released OpenCode path already carried fileData parts.
          // Remove this mapping with support for those bridges.
          plugins: [
            for (final plugin in data.plugins)
              if (!data.supportsSessionOptions && plugin.id == legacyMissingPluginId)
                plugin.copyWith(supportsPromptAttachments: true)
              else
                plugin,
          ],
        ),
      ),
      // COMPATIBILITY 2026-07-18 (v1.6.0): Bridges without plugin
      // discovery return 404 and can only target OpenCode. Remove this
      // fallback once those bridges are unsupported.
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: false,
          plugins: [
            const PluginMetadata(
              id: legacyMissingPluginId,
              displayName: "OpenCode",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
              supportsPromptAttachments: true,
            ),
          ],
        ),
      ),
      ErrorResponse(:final error) => ApiResponse.error(error),
    };
  }
}

sealed class const _AuthenticationConflictParseResult();

final class const _AuthenticationConflictParsed({required final PluginAuthenticationConflict conflict})
    extends _AuthenticationConflictParseResult;

final class const _AuthenticationConflictParseFailure({required final ApiError error})
    extends _AuthenticationConflictParseResult;

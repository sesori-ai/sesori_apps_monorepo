import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/models/mcp_authentication_response.dart";
import "../../repositories/models/plugin_management_result.dart";
import "../plugin_authentication_browser_service.dart";

/// Native truth, transport work and local browser presentation are independent.
final class const McpAuthenticationClientState({
  required final McpAuthenticationObservation observation,
  required final McpAuthenticationRequestState request,
  required final McpAuthenticationBrowserState browser,
});

sealed class const McpAuthenticationObservation();
final class const McpAuthenticationOffline() extends McpAuthenticationObservation;
final class const McpAuthenticationLoading() extends McpAuthenticationObservation;
final class const McpAuthenticationIdentityUnavailable({required final PluginManagementLoadResult cause})
    extends McpAuthenticationObservation;
final class const McpAuthenticationObserved({
  required final McpAuthenticationState state,
  required final McpAuthenticationResponse? refreshFailure,
}) extends McpAuthenticationObservation;
final class const McpAuthenticationReadFailure({required final McpAuthenticationResponse response})
    extends McpAuthenticationObservation;

enum McpAuthenticationRequestKind() {
  start,
  continuation,
  cancellation,
}

sealed class const McpAuthenticationRequestState();
final class const McpAuthenticationRequestIdle() extends McpAuthenticationRequestState;
final class const McpAuthenticationRequestPending({required final McpAuthenticationRequestKind kind})
    extends McpAuthenticationRequestState;

/// Failed transport does not prove a dispatched native mutation failed.
final class const McpAuthenticationRequestUncertain({required final ApiError cause})
    extends McpAuthenticationRequestState;
final class const McpAuthenticationRequestRejected({required final McpAuthenticationResponse response})
    extends McpAuthenticationRequestState;

sealed class const McpAuthenticationBrowserState();
final class const McpAuthenticationBrowserIdle() extends McpAuthenticationBrowserState;
final class const McpAuthenticationBrowserOpening() extends McpAuthenticationBrowserState;
final class const McpAuthenticationBrowserWaiting() extends McpAuthenticationBrowserState;
final class const McpAuthenticationBrowserBlocked() extends McpAuthenticationBrowserState;
final class const McpAuthenticationBrowserFailed({required final PluginAuthenticationBrowserFlowFailed failure})
    extends McpAuthenticationBrowserState;

McpAuthenticationAttempt? mcpAuthenticationAttempt({required McpAuthenticationState state}) => switch (state) {
  McpAuthenticationStarting(:final attempt) ||
  McpAuthenticationCallbackChallenge(:final attempt) ||
  McpAuthenticationSettling(:final attempt) ||
  McpAuthenticationCompleted(:final attempt) ||
  McpAuthenticationFailed(:final attempt) ||
  McpAuthenticationCancelled(:final attempt) => attempt,
  McpAuthenticationUnknown() || McpAuthenticationIdle() => null,
};

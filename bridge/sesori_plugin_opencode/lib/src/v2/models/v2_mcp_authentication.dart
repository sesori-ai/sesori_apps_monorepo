import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../models/open_code_mcp_login_challenge.dart";

final class const V2McpAuthenticationException({required final Object innerError}) implements Exception {
  @override
  String toString() => "OpenCode MCP authentication failed (${innerError.runtimeType})";
}

final class const V2McpAuthenticationStartRejected({required final Object innerError}) implements Exception;

final class const V2McpAuthenticationTarget({
  required final String directory,
  required final String integrationId,
  required final String methodId,
});

sealed class const V2McpAuthenticationAttempt({required final String attemptId});
final class const V2McpAuthenticationReady({
  required super.attemptId,
  required final OpenCodeMcpLoginChallenge challenge,
}) extends V2McpAuthenticationAttempt;
final class const V2McpAuthenticationInvalid({
  required super.attemptId,
  required final Object cause,
  required final StackTrace stackTrace,
}) extends V2McpAuthenticationAttempt;

sealed class const V2McpAuthenticationObservation();
final class const V2McpAuthenticationPending() extends V2McpAuthenticationObservation;
final class const V2McpAuthenticationUnknown() extends V2McpAuthenticationObservation;
final class const V2McpAuthenticationRemoved({required final Object innerError, required final StackTrace stackTrace})
    extends V2McpAuthenticationObservation;
final class const V2McpAuthenticationTerminal({required final PluginMcpAuthenticationEvent event})
    extends V2McpAuthenticationObservation;

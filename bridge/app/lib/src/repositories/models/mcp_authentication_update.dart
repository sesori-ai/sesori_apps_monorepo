import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const McpAuthenticationUpdate();

final class const McpAuthenticationStarted({
  required final PluginMcpAuthenticationOperation operation,
  required final void Function() activate,
}) extends McpAuthenticationUpdate;

final class const McpAuthenticationNativeEvent({required final PluginMcpAuthenticationEvent event})
    extends McpAuthenticationUpdate;

final class const McpAuthenticationUnavailableException({required final McpAuthenticationUnavailableReason reason})
    implements Exception;

/// Callback causes are retained without displaying their private payload.
final class const McpAuthenticationCallbackException({required final Object innerError}) implements Exception {
  @override
  String toString() => "MCP authentication callback failed";
}

final class const McpAuthenticationCancellationException({required final Object innerError}) implements Exception {
  @override
  String toString() => "MCP authentication cancellation failed";
}

final class const McpAuthenticationDestinationException() implements Exception {
  @override
  String toString() => "MCP authentication requires an absolute HTTPS authorization destination without user info";
}

final class const McpAuthenticationCleanupException({
  required final Object innerError,
  required final StackTrace innerStackTrace,
  required final Object cleanupError,
  required final StackTrace cleanupStackTrace,
}) implements Exception {
  @override
  String toString() => "MCP authentication failed with a native cleanup failure";
}

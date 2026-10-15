import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Retains native/HTTP causes without printing authorization URLs or callbacks.
final class const CodexMcpAuthenticationException({required final Object innerError}) implements Exception {
  @override
  String toString() => switch (innerError) {
    final CodexMcpLoginRejectedException error => error.toString(),
    final CodexMcpNativeOAuthException error => error.toString(),
    _ => "Codex MCP authentication failed (${innerError.runtimeType})",
  };
}

final class const CodexMcpLoginRejectedException({required final Object innerError, required final int code})
    implements Exception {
  @override
  String toString() => "Codex MCP login rejected (RPC $code)";
}

final class const CodexMcpNativeOAuthException({
  required final String? message,
  required final PluginMcpAuthenticationFailureReason reason,
}) implements Exception {
  @override
  String toString() => "Codex MCP native authentication failed: ${reason.name}";
}

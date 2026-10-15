import "open_code_mcp_login_challenge.dart";

final class const OpenCodeMcpAuthenticationException({required final Object innerError}) implements Exception {
  @override
  String toString() => "OpenCode MCP authentication failed (${innerError.runtimeType})";
}

final class const OpenCodeMcpAuthenticationStartRejected({required final Object innerError}) implements Exception;

final class const OpenCodeMcpAuthenticationTarget({required final String directory, required final String name});

sealed class const OpenCodeMcpAuthenticationStart();
final class const OpenCodeMcpAlreadyAuthorized() extends OpenCodeMcpAuthenticationStart;
final class const OpenCodeMcpAuthenticationChallenge({required final OpenCodeMcpLoginChallenge challenge})
    extends OpenCodeMcpAuthenticationStart;

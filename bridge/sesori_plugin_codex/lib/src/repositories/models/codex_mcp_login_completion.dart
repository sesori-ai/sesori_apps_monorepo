import "codex_mcp_authentication_exception.dart";

sealed class const CodexMcpLoginCompletion({required final String name, required final String? threadId});

final class const CodexMcpLoginCompleted({required super.name, required super.threadId})
    extends CodexMcpLoginCompletion;

final class const CodexMcpLoginFailed({
  required super.name,
  required super.threadId,
  required final CodexMcpNativeOAuthException cause,
}) extends CodexMcpLoginCompletion;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../codex_app_server_client.dart";

/// Codex refused a stored thread because the model provider it was started
/// with cannot be used under the current Codex configuration. A conflict with
/// the user's setup, not a bridge failure, so clients show the short message
/// naming the providers and the fix.
sealed class CodexModelProviderException({
  required String operation,

  /// The provider the thread was started with.
  required final String threadProvider,
  required String message,
  required CodexRpcException cause,
}) extends PluginRefusalException {
  this : super(operation, userFacingReason: message, cause: cause);
}

final class CodexModelProviderMismatchException({
  required super.operation,
  required super.threadProvider,

  /// The provider Codex is currently configured with.
  required final String currentProvider,
  required super.cause,
}) extends CodexModelProviderException {
  this
    : super(
        message:
            "This session uses the $threadProvider model provider, but Codex is set to $currentProvider. "
            "Switch Codex back to $threadProvider to continue it.",
      );
}

final class CodexModelProviderNotConfiguredException({
  required super.operation,
  required super.threadProvider,
  required super.cause,
}) extends CodexModelProviderException {
  this
    : super(
        message:
            "This session uses the $threadProvider model provider, which Codex no longer has configured. "
            "Add $threadProvider back to the Codex config to continue it.",
      );
}

final class CodexModelProviderPolicyConflictException({
  required super.operation,
  required super.threadProvider,

  /// The provider the active Codex policy requires.
  required final String requiredProvider,
  required super.cause,
}) extends CodexModelProviderException {
  this
    : super(
        message:
            "This session uses the $threadProvider model provider, but your Codex policy requires "
            "$requiredProvider, so it can't be continued.",
      );
}

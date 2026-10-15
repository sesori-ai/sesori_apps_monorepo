import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_app_server_api.dart";
import "../api/codex_mcp_callback_api.dart";
import "../api/models/codex_mcp_oauth_dto.dart";
import "../codex_app_server_client.dart";
import "codex_mcp_repository.dart";
import "models/codex_mcp_authentication_exception.dart";
import "models/codex_mcp_login_challenge.dart";
import "models/codex_mcp_login_completion.dart";

class CodexMcpAuthenticationRepository({
  required final CodexAppServerApi _appServerApi,
  required final CodexMcpRepository _inventory,
  required final CodexMcpCallbackApi _callbackApi,
  required final int _timeoutSecs,
}) {
  Stream<CodexMcpLoginCompletion> get completions => _appServerApi.mcpOAuthCompletions.map((completion) {
    if (completion.success) return CodexMcpLoginCompleted(name: completion.name, threadId: completion.threadId);
    final reason = switch (completion.failureKind) {
      CodexMcpOAuthFailureKind.expired => PluginMcpAuthenticationFailureReason.expired,
      CodexMcpOAuthFailureKind.declined => PluginMcpAuthenticationFailureReason.declined,
      CodexMcpOAuthFailureKind.nativeFailure => PluginMcpAuthenticationFailureReason.nativeFailure,
    };
    return CodexMcpLoginFailed(
      name: completion.name,
      threadId: completion.threadId,
      cause: CodexMcpNativeOAuthException(message: completion.error, reason: reason),
    );
  });

  Future<void> validateTarget({required PluginMcpServerTarget target}) async {
    final result = await _inventory.read(scope: target.scope);
    switch (result) {
      case PluginMcpInventoryUnavailable(:final reason):
        throw PluginMcpAuthenticationUnavailableException(
          reason: switch (reason) {
            PluginMcpInventoryUnavailableReason.unsupportedScope =>
              PluginMcpAuthenticationUnavailableReason.unsupportedScope,
            PluginMcpInventoryUnavailableReason.liveSessionRequired =>
              PluginMcpAuthenticationUnavailableReason.liveSessionRequired,
          },
        );
      case PluginMcpInventoryReadFailed(:final cause, :final causeStackTrace):
        Error.throwWithStackTrace(CodexMcpAuthenticationException(innerError: cause), causeStackTrace);
      case PluginMcpInventorySnapshot(:final entries):
        for (final entry in entries) {
          if (entry is! PluginMcpServerSnapshot || entry.target.serverKey != target.serverKey) continue;
          if (entry.authentication case PluginMcpAuthenticationCapabilityUnavailable(:final reason)) {
            throw PluginMcpAuthenticationUnavailableException(
              reason: switch (reason) {
                PluginMcpAuthenticationCapabilityUnavailableReason.notSupported =>
                  PluginMcpAuthenticationUnavailableReason.notSupported,
                PluginMcpAuthenticationCapabilityUnavailableReason.notImplemented =>
                  PluginMcpAuthenticationUnavailableReason.notImplemented,
                PluginMcpAuthenticationCapabilityUnavailableReason.nativeConfigurationRequired =>
                  PluginMcpAuthenticationUnavailableReason.nativeConfigurationRequired,
              },
            );
          }
          return;
        }
        throw const PluginMcpAuthenticationUnavailableException(
          reason: PluginMcpAuthenticationUnavailableReason.targetNotFound,
        );
    }
  }

  Future<CodexMcpLoginChallenge> start({required PluginMcpServerTarget target}) async {
    final response = await _appServerApi
        .startMcpOAuth(
          name: target.serverKey,
          threadId: switch (target.scope) {
            PluginMcpSessionScope(:final sessionId) => sessionId,
            PluginMcpHarnessScope() => null,
            PluginMcpProjectScope() => throw const PluginMcpAuthenticationUnavailableException(
              reason: PluginMcpAuthenticationUnavailableReason.unsupportedScope,
            ),
          },
          timeoutSecs: _timeoutSecs,
        )
        .onError<CodexRpcException>(
          (error, stackTrace) => Error.throwWithStackTrace(
            CodexMcpLoginRejectedException(innerError: error, code: error.code),
            stackTrace,
          ),
        );
    return CodexMcpLoginChallenge.parse(value: response.authorizationUrl);
  }

  Future<void> submitCallback({required CodexMcpLoginChallenge challenge, required Uri callbackUri}) async {
    try {
      challenge.validateCallback(callback: callbackUri);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(PluginMcpAuthenticationCallbackRejectedException(innerError: error), stackTrace);
    }
    try {
      await _callbackApi.submit(callbackUri: callbackUri);
    } on CodexMcpCallbackHttpException catch (error, stackTrace) {
      // Both pins consume provider denial with HTTP 400, then emit the native
      // failure notification. Delivery is complete; settlement remains native.
      if (error.statusCode == 400 && (callbackUri.queryParameters["error"]?.isNotEmpty ?? false)) return;
      Error.throwWithStackTrace(CodexMcpAuthenticationException(innerError: error), stackTrace);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(CodexMcpAuthenticationException(innerError: error), stackTrace);
    }
  }

  void close() => _callbackApi.close();
}

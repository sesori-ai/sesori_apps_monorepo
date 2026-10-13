import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/claude_mcp_authentication_repository.dart";
import "../repositories/claude_mcp_login_repository.dart";
import "../repositories/models/claude_mcp_authentication_context.dart";
import "../repositories/models/claude_mcp_command_exception.dart";
import "../repositories/parsers/claude_mcp_login_output_parser.dart";

/// Native login failure diagnostics keep the cause without printing auth output.
final class const ClaudeMcpAuthenticationException({required final Object innerError}) implements Exception {
  @override
  String toString() => switch (innerError) {
    ClaudeMcpCommandExitedException(:final exitCode) => "Claude MCP authentication exited with code $exitCode",
    TimeoutException() => "Claude MCP authentication timed out",
    ClaudeMcpLoginTrustRequiredException() =>
      "Approve this configured MCP server in the native harness before signing in",
    final ClaudeMcpProviderCallbackException error => error.toString(),
    _ => "Claude MCP authentication failed",
  };
}

/// Owns one native login event stream and stops its child before settlement.
typedef ClaudeMcpAuthenticationContextResolver = Future<ClaudeMcpAuthenticationContext> Function({
  required PluginMcpServerTarget target,
});
typedef ClaudeMcpLoginRepositoryFactory = ClaudeMcpLoginRepository Function({
  required ClaudeMcpAuthenticationContext context,
});

/// Sequential native and cleanup failures retain both causes and stack traces.
final class const ClaudeMcpAuthenticationCleanupException({
  required final Exception innerError,
  required final StackTrace innerStackTrace,
  required final ClaudeMcpAuthenticationException cleanupError,
  required final StackTrace cleanupStackTrace,
}) implements Exception {
  @override
  String toString() => "$innerError; $cleanupError during native cleanup";
}

final class ClaudeMcpAuthenticationService({
  required final ClaudeMcpAuthenticationRepository _repository,
  required final ClaudeMcpAuthenticationContextResolver _resolveContext,
  required final ClaudeMcpLoginRepositoryFactory _createLogin,
  required final Duration _urlBudget,
  required final Duration _overallBudget,
}) {
  Future<PluginMcpAuthenticationOperation> begin({required PluginMcpServerTarget target}) async {
    final context = await _authenticationContext(target: target);
    final login = _createLogin(context: context);
    return _ClaudeMcpLoginService(
      repository: login,
      urlBudget: _urlBudget,
      overallBudget: _overallBudget,
    ).authenticate();
  }

  Future<void> forget({required PluginMcpServerTarget target}) async {
    final context = await _authenticationContext(target: target);
    await _repository.forget(context: context);
  }

  Future<ClaudeMcpAuthenticationContext> _authenticationContext({required PluginMcpServerTarget target}) async {
    try {
      return await _resolveContext(target: target);
    } on PluginMcpAuthenticationUnavailableException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(ClaudeMcpAuthenticationException(innerError: error), stackTrace);
    }
  }
}

sealed class const _ClaudeMcpLoginTermination();
final class const _ClaudeMcpLoginActive() extends _ClaudeMcpLoginTermination;
final class const _ClaudeMcpLoginCancelled() extends _ClaudeMcpLoginTermination;
final class const _ClaudeMcpLoginProviderRejected({required final ClaudeMcpProviderCallbackException cause})
    extends _ClaudeMcpLoginTermination;

/// One child and event stream, kept separate from the reusable authentication service.
final class _ClaudeMcpLoginService({
  required final ClaudeMcpLoginRepository _repository,
  required final Duration _urlBudget,
  required final Duration _overallBudget,
}) {
  _ClaudeMcpLoginTermination _termination = const _ClaudeMcpLoginActive();

  PluginMcpCancelableAuthentication authenticate() {
    late final StreamController<PluginMcpAuthenticationEvent> events;
    events = StreamController(
      onListen: () {
        if (_termination is _ClaudeMcpLoginCancelled) {
          unawaited(events.close());
        } else {
          unawaited(_run(events: events));
        }
      },
      onCancel: _cancel,
    );
    return PluginMcpCancelableAuthentication(
      effectScope: PluginMcpActionEffectScope.harness,
      events: events.stream,
      submitCallback: _submitCallback,
      cancel: _cancel,
    );
  }

  Future<void> _run({required StreamController<PluginMcpAuthenticationEvent> events}) async {
    final elapsed = Stopwatch()..start();
    PluginMcpAuthenticationEvent outcome;
    try {
      final challenge = await _repository.start().timeout(_urlBudget);
      events.add(
        PluginMcpAuthenticationChallenge(
          authorizationUri: challenge.authorizationUri,
          expectedCallbackUri: challenge.callbackUri,
        ),
      );
      final code = await _repository.waitForExit().timeout(_overallBudget - elapsed.elapsed);
      if (_termination case _ClaudeMcpLoginProviderRejected(:final cause)) throw cause;
      if (code != 0) throw ClaudeMcpCommandExitedException(exitCode: code);
      outcome = const PluginMcpAuthenticationCompleted();
    } on Object catch (error, stackTrace) {
      final failure = ClaudeMcpAuthenticationException(innerError: error);
      outcome = PluginMcpAuthenticationFailed(
        reason: switch (_termination) {
          _ClaudeMcpLoginProviderRejected(:final cause) when cause.reason == ClaudeMcpOAuthFailure.accessDenied =>
            PluginMcpAuthenticationFailureReason.declined,
          _ => switch (error) {
            TimeoutException() => PluginMcpAuthenticationFailureReason.expired,
            ClaudeMcpLoginTrustRequiredException() => PluginMcpAuthenticationFailureReason.nativeTrustRequired,
            _ => PluginMcpAuthenticationFailureReason.nativeFailure,
          },
        },
        cause: failure,
        causeStackTrace: stackTrace,
      );
      if (_termination is _ClaudeMcpLoginCancelled &&
          error is! ClaudeMcpCommandExitedException &&
          error is! TimeoutException) {
        Log.w("[claude] MCP authentication failed during cancellation", failure, stackTrace);
      }
    }
    try {
      await _repository.dispose();
    } on Object catch (error, stackTrace) {
      final cleanup = ClaudeMcpAuthenticationException(innerError: error);
      final failure = switch (outcome) {
        PluginMcpAuthenticationFailed(:final reason, :final cause, :final causeStackTrace) =>
          PluginMcpAuthenticationFailed(
            reason: reason,
            cause: ClaudeMcpAuthenticationCleanupException(
              innerError: cause,
              innerStackTrace: causeStackTrace,
              cleanupError: cleanup,
              cleanupStackTrace: stackTrace,
            ),
            causeStackTrace: causeStackTrace,
          ),
        _ => PluginMcpAuthenticationFailed(
          reason: PluginMcpAuthenticationFailureReason.nativeFailure,
          cause: cleanup,
          causeStackTrace: stackTrace,
        ),
      };
      outcome = failure;
      if (_termination is _ClaudeMcpLoginCancelled) {
        Log.w("[claude] MCP authentication cleanup failed", failure.cause, failure.causeStackTrace);
        if (failure.cause case ClaudeMcpAuthenticationCleanupException(:final cleanupError, :final cleanupStackTrace)) {
          Log.w("[claude] MCP authentication cleanup failed during native settlement", cleanupError, cleanupStackTrace);
        }
      }
    }
    // Terminal settlement already attempted disposal; closing the stream must
    // not repeat a failed cleanup through its cancellation callback.
    events.onCancel = null;
    if (_termination is! _ClaudeMcpLoginCancelled) events.add(outcome);
    unawaited(events.close());
  }

  Future<void> _submitCallback({required Uri callbackUri}) async {
    if (_termination is _ClaudeMcpLoginCancelled) {
      throw PluginMcpAuthenticationCallbackRejectedException(
        innerError: StateError("MCP authentication was cancelled"),
      );
    }
    final result = await _repository.submitCallback(callback: callbackUri.toString());
    // A browser return can finish while the user cancels the active sign-in.
    if (_termination is _ClaudeMcpLoginCancelled) return;
    if (result case ClaudeMcpCallbackRejected(:final cause)) {
      _termination = _ClaudeMcpLoginProviderRejected(cause: cause);
      await _repository.dispose();
    }
  }

  Future<void> _cancel() {
    _termination = const _ClaudeMcpLoginCancelled();
    return _repository.dispose();
  }
}

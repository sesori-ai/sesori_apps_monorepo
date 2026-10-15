import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/codex_mcp_authentication_repository.dart";
import "../repositories/models/codex_mcp_authentication_exception.dart";
import "../repositories/models/codex_mcp_login_challenge.dart";
import "../repositories/models/codex_mcp_login_completion.dart";

sealed class const _Ownership();
final class const _Idle() extends _Ownership;
final class const _Running({required final _CodexMcpLogin login}) extends _Ownership;
final class const _Disposed() extends _Ownership;

/// Native resources only; the bridge owns cross-client attempts and serialization.
class CodexMcpAuthenticationService({required final CodexMcpAuthenticationRepository _repository}) {
  _Ownership _ownership = const _Idle();

  Future<PluginMcpAuthenticationOperation> begin({required PluginMcpServerTarget target}) async {
    if (_ownership is _Disposed) {
      throw const PluginMcpAuthenticationUnavailableException(
        reason: PluginMcpAuthenticationUnavailableReason.liveSessionRequired,
      );
    }
    await _repository.validateTarget(target: target);
    late final _CodexMcpLogin login;
    login = _CodexMcpLogin(
      repository: _repository,
      target: target,
      activate: () {
        if (_ownership is _Disposed) throw StateError("Codex runtime disconnected before MCP login");
        _ownership = _Running(login: login);
      },
      release: () {
        if (_ownership case _Running(login: final current) when identical(current, login)) _ownership = const _Idle();
      },
    );
    return login.operation();
  }

  Future<void> dispose() async {
    final previous = _ownership;
    _ownership = const _Disposed();
    _repository.close();
    if (previous case _Running(:final login)) await login.retire();
  }
}

final class _CodexMcpLogin({
  required final CodexMcpAuthenticationRepository _repository,
  required final PluginMcpServerTarget _target,
  required final void Function() _activate,
  required final void Function() _release,
}) {
  final _settlement = Completer<PluginMcpAuthenticationEvent>();
  final _done = Completer<void>();
  CodexMcpLoginChallenge? _challenge;

  PluginMcpNativeSettlementAuthentication operation() {
    late final StreamController<PluginMcpAuthenticationEvent> events;
    events = StreamController(onListen: () => unawaited(_run(events: events)));
    return PluginMcpNativeSettlementAuthentication(
      effectScope: PluginMcpActionEffectScope.harness,
      events: events.stream,
      submitCallback: _submitCallback,
    );
  }

  Future<void> _run({required StreamController<PluginMcpAuthenticationEvent> events}) async {
    StreamSubscription<CodexMcpLoginCompletion>? subscription;
    try {
      _activate();
      subscription = _repository.completions.listen(
        (completion) {
          if (completion.name != _target.serverKey) return;
          final threadId = switch (_target.scope) {
            PluginMcpSessionScope(:final sessionId) => sessionId,
            _ => null,
          };
          if (completion.threadId != null && completion.threadId != threadId) return;
          _complete(
            event: switch (completion) {
              CodexMcpLoginCompleted() => const PluginMcpAuthenticationCompleted(),
              CodexMcpLoginFailed(:final cause) => _failure(
                error: cause,
                stackTrace: StackTrace.current,
                reason: cause.reason,
              ),
            },
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          // Malformed native data is not proof that its pending login stopped.
          Log.w(
            "[codex] MCP completion could not be decoded; retaining native ownership",
            CodexMcpAuthenticationException(innerError: error),
            stackTrace,
          );
        },
        onDone: () => _complete(
          event: _failure(error: StateError("Codex MCP completion stream closed"), stackTrace: StackTrace.current),
        ),
      );
      unawaited(_start(events: events));
    } on Object catch (error, stackTrace) {
      _complete(
        event: _failure(error: error, stackTrace: stackTrace),
      );
    }
    final outcome = await _settlement.future;
    try {
      await subscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] MCP authentication observation cleanup failed",
        CodexMcpAuthenticationException(innerError: error),
        stackTrace,
      );
    }
    if (!events.hasListener) {
      if (outcome case PluginMcpAuthenticationFailed(:final cause, :final causeStackTrace)) {
        Log.w("[codex] Unobserved MCP authentication failure", cause, causeStackTrace);
      }
    }
    events.add(outcome);
    unawaited(events.close());
    _release();
    _done.complete();
  }

  Future<void> _start({required StreamController<PluginMcpAuthenticationEvent> events}) async {
    try {
      final challenge = await _repository.start(target: _target);
      if (_settlement.isCompleted) return;
      _challenge = challenge;
      events.add(
        PluginMcpAuthenticationChallenge(
          authorizationUri: challenge.authorizationUri,
          expectedCallbackUri: challenge.callbackUri,
        ),
      );
    } on CodexMcpLoginRejectedException catch (error, stackTrace) {
      _complete(
        event: _failure(error: error, stackTrace: stackTrace),
      );
    } on Object catch (error, stackTrace) {
      if (_settlement.isCompleted) return;
      // A lost/malformed successful reply can still own a native callback wait.
      Log.w(
        "[codex] MCP login response uncertain; awaiting native settlement",
        CodexMcpAuthenticationException(innerError: error),
        stackTrace,
      );
    }
  }

  Future<void> _submitCallback({required Uri callbackUri}) async {
    final challenge = _challenge;
    if (challenge == null || _settlement.isCompleted) {
      throw PluginMcpAuthenticationCallbackRejectedException(
        innerError: StateError("Codex MCP login is not awaiting a callback"),
      );
    }
    await _repository.submitCallback(challenge: challenge, callbackUri: callbackUri);
  }

  void _complete({required PluginMcpAuthenticationEvent event}) {
    if (!_settlement.isCompleted) _settlement.complete(event);
  }

  Future<void> retire() {
    _complete(
      event: _failure(error: StateError("Codex runtime disconnected during MCP login"), stackTrace: StackTrace.current),
    );
    return _done.future;
  }
}

PluginMcpAuthenticationFailed _failure({
  required Object error,
  required StackTrace stackTrace,
  PluginMcpAuthenticationFailureReason reason = PluginMcpAuthenticationFailureReason.nativeFailure,
}) => PluginMcpAuthenticationFailed(
  reason: reason,
  cause: CodexMcpAuthenticationException(innerError: error),
  causeStackTrace: stackTrace,
);

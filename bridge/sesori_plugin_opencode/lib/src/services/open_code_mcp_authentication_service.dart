import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/open_code_mcp_authentication.dart";
import "../models/open_code_mcp_login_challenge.dart";
import "../opencode_repository.dart";

sealed class const _Ownership();
final class const _Idle() extends _Ownership;
final class const _Running({required final _OpenCodeMcpLogin login}) extends _Ownership;
final class const _Disposed() extends _Ownership;

/// V1 has manual callback settlement and no credential-preserving cancellation.
class OpenCodeMcpAuthenticationService({
  required final OpenCodeRepository _repository,
}) {
  _Ownership _ownership = const _Idle();

  Future<String> _directory({required PluginMcpScope scope}) async {
    final directory = await _repository.getMcpDirectory(scope: scope);
    if (directory == null) {
      throw const PluginMcpAuthenticationUnavailableException(
        reason: PluginMcpAuthenticationUnavailableReason.unsupportedScope,
      );
    }
    return directory;
  }

  Future<PluginMcpAuthenticationOperation> begin({required PluginMcpServerTarget target}) async {
    if (_ownership is _Disposed) throw StateError("OpenCode runtime has stopped");
    final directory = await _directory(scope: target.scope);
    final native = await _repository.prepareMcpAuthentication(directory: directory, name: target.serverKey);
    final login = _OpenCodeMcpLogin(repository: _repository, target: native);
    return login.operation(
      activate: () {
        if (_ownership is _Disposed) throw StateError("OpenCode runtime stopped before MCP login");
        _ownership = _Running(login: login);
        unawaited(
          login.done.whenComplete(() {
            if (_ownership case _Running(login: final current) when identical(current, login)) {
              _ownership = const _Idle();
            }
          }),
        );
      },
    );
  }

  Future<PluginMcpActionEffectScope> forget({required PluginMcpServerTarget target}) async {
    if (_ownership is _Disposed) throw StateError("OpenCode runtime has stopped");
    final directory = await _directory(scope: target.scope);
    await _repository.forgetMcpAuthentication(directory: directory, name: target.serverKey);
    return PluginMcpActionEffectScope.harness;
  }

  Future<void> dispose() async {
    final previous = _ownership;
    _ownership = const _Disposed();
    if (previous case _Running(:final login)) login.retire();
  }
}

sealed class const _LoginState();
final class const _Starting() extends _LoginState;
final class const _Waiting({required final OpenCodeMcpLoginChallenge challenge}) extends _LoginState;
final class const _Uncertain() extends _LoginState;
final class const _Retired() extends _LoginState;

final class _OpenCodeMcpLogin({
  required final OpenCodeRepository _repository,
  required final OpenCodeMcpAuthenticationTarget _target,
}) {
  _LoginState _state = const _Starting();
  final _done = Completer<void>();
  late final StreamController<PluginMcpAuthenticationEvent> _events;
  Future<void> get done => _done.future;

  PluginMcpNativeSettlementAuthentication operation({required void Function() activate}) {
    _events = StreamController(
      onListen: () {
        try {
          activate();
          unawaited(_start());
        } on Object catch (error, stackTrace) {
          _finish(
            event: _failure(error: error, stackTrace: stackTrace),
          );
        }
      },
      onCancel: retire,
    );
    return PluginMcpNativeSettlementAuthentication(
      effectScope: PluginMcpActionEffectScope.harness,
      events: _events.stream,
      submitCallback: _submitCallback,
    );
  }

  Future<void> _start() async {
    try {
      final result = await _repository.startMcpAuthentication(target: _target);
      if (_state is _Retired) return;
      switch (result) {
        case OpenCodeMcpAlreadyAuthorized():
          _finish(event: const PluginMcpAuthenticationCompleted());
        case OpenCodeMcpAuthenticationChallenge(:final challenge):
          _state = _Waiting(challenge: challenge);
          _events.add(
            PluginMcpAuthenticationChallenge(
              authorizationUri: challenge.authorizationUri,
              expectedCallbackUri: challenge.callbackUri,
            ),
          );
      }
    } on OpenCodeMcpAuthenticationStartRejected catch (error, stackTrace) {
      _finish(
        event: _failure(error: error, stackTrace: stackTrace),
      );
    } on Object catch (error, stackTrace) {
      if (_state is _Retired) return;
      _state = const _Uncertain();
      Log.w("[opencode-v1] MCP start uncertain for ${_target.name}; retaining native ownership", error, stackTrace);
    }
  }

  Future<void> _submitCallback({required Uri callbackUri}) async {
    final current = _state;
    if (current is! _Waiting) {
      throw PluginMcpAuthenticationCallbackRejectedException(innerError: StateError("No active native MCP challenge"));
    }
    try {
      final result = await _repository.completeMcpAuthentication(
        target: _target,
        challenge: current.challenge,
        callbackUri: callbackUri,
      );
      _finish(event: result);
    } on PluginMcpAuthenticationCallbackRejectedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      if (_state is! _Retired) {
        _state = const _Uncertain();
        Log.w(
          "[opencode-v1] MCP callback outcome uncertain for ${_target.name}; retaining native ownership",
          error,
          stackTrace,
        );
      }
      Error.throwWithStackTrace(OpenCodeMcpAuthenticationException(innerError: error), stackTrace);
    }
  }

  void retire() {
    if (_state is _Retired) return;
    // DELETE auth also destroys credentials; it is never safe runtime cleanup.
    Log.w("[opencode-v1] Retiring MCP observation for ${_target.name}; native pending cleanup is unavailable");
    _finish(
      event: _failure(error: StateError("OpenCode runtime stopped"), stackTrace: StackTrace.current),
    );
  }

  PluginMcpAuthenticationFailed _failure({required Object error, required StackTrace stackTrace}) =>
      PluginMcpAuthenticationFailed(
        reason: PluginMcpAuthenticationFailureReason.nativeFailure,
        cause: OpenCodeMcpAuthenticationException(innerError: error),
        causeStackTrace: stackTrace,
      );

  void _finish({required PluginMcpAuthenticationEvent event}) {
    if (_state is _Retired) return;
    _state = const _Retired();
    _events.onCancel = null;
    _events.add(event);
    unawaited(_events.close());
    _done.complete();
  }
}

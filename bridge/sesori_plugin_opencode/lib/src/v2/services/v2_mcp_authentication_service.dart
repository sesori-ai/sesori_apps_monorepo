import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../open_code_raw_http_client.dart";
import "../models/v2_mcp_authentication.dart";
import "../repositories/opencode_v2_repository.dart";

sealed class const _Ownership();
final class const _Idle() extends _Ownership;
final class const _Running({required final _V2McpLogin login}) extends _Ownership;
final class const _Disposed() extends _Ownership;

/// Owns native resources; cross-client exclusion belongs to the headless owner.
class V2McpAuthenticationService({
  required final OpenCodeV2Repository _repository,
  required final Duration _pollInterval,
}) {
  _Ownership _ownership = const _Idle();

  Future<PluginMcpAuthenticationOperation> begin({
    required String directory,
    required PluginMcpServerTarget target,
  }) async {
    if (_ownership is _Disposed) throw StateError("OpenCode runtime has stopped");
    final native = await _repository.prepareMcpAuthentication(directory: directory, name: target.serverKey);
    final login = _V2McpLogin(repository: _repository, target: native, pollInterval: _pollInterval);
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

  Future<PluginMcpActionEffectScope> forget({required String directory, required PluginMcpServerTarget target}) async {
    if (_ownership is _Disposed) throw StateError("OpenCode runtime has stopped");
    await _repository.forgetMcpAuthentication(directory: directory, name: target.serverKey);
    return PluginMcpActionEffectScope.harness;
  }

  Future<void> dispose() async {
    final previous = _ownership;
    _ownership = const _Disposed();
    if (previous case _Running(:final login)) await login.retire();
  }
}

sealed class const _LoginState();
final class const _Preparing() extends _LoginState;
final class const _Active({required final V2McpAuthenticationAttempt attempt}) extends _LoginState;
final class const _Uncertain() extends _LoginState;
final class const _Retired() extends _LoginState;

final class _V2McpLogin({
  required final OpenCodeV2Repository _repository,
  required final V2McpAuthenticationTarget _target,
  required final Duration _pollInterval,
}) {
  _LoginState _state = const _Preparing();
  final _started = Completer<void>();
  final _done = Completer<void>();
  late final StreamController<PluginMcpAuthenticationEvent> _events;
  Future<void>? _cancellation;

  Future<void> get done => _done.future;

  PluginMcpCancelableAuthentication operation({required void Function() activate}) {
    _events = StreamController(
      onListen: () {
        try {
          activate();
          unawaited(_run());
        } on Object catch (error, stackTrace) {
          _finish(
            event: _failure(error: error, stackTrace: stackTrace),
          );
        }
      },
      onCancel: _cancel,
    );
    return PluginMcpCancelableAuthentication(
      effectScope: PluginMcpActionEffectScope.harness,
      events: _events.stream,
      submitCallback: _submitCallback,
      cancel: _cancel,
    );
  }

  Future<void> _run() async {
    try {
      final attempt = await _repository.startMcpAuthentication(target: _target);
      if (_state is _Retired) {
        try {
          await _repository.cancelMcpAuthentication(target: _target, attemptId: attempt.attemptId);
        } on Object catch (error, stackTrace) {
          Log.w("[opencode-v2] Retired MCP start cleanup failed for ${_target.integrationId}", error, stackTrace);
        }
        return;
      }
      _state = _Active(attempt: attempt);
      if (attempt case V2McpAuthenticationReady(:final challenge)) {
        _events.add(
          PluginMcpAuthenticationChallenge(
            authorizationUri: challenge.authorizationUri,
            expectedCallbackUri: challenge.callbackUri,
          ),
        );
      }
    } on V2McpAuthenticationStartRejected catch (error, stackTrace) {
      _finish(
        event: _failure(error: error, stackTrace: stackTrace),
      );
    } on Object catch (error, stackTrace) {
      if (_state is! _Retired) {
        _state = const _Uncertain();
        Log.w(
          "[opencode-v2] MCP start uncertain for ${_target.integrationId}; retaining native ownership",
          error,
          stackTrace,
        );
      }
    } finally {
      _started.complete();
    }
    if (_state case _Active(attempt: V2McpAuthenticationInvalid())) {
      // An unusable challenge still owns the returned native attempt.
      unawaited(
        _cancel().catchError((Object error, StackTrace stackTrace) {
          Log.w("[opencode-v2] Invalid MCP challenge cleanup failed for ${_target.integrationId}", error, stackTrace);
        }),
      );
    }
    while (_state is _Active) {
      final attempt = (_state as _Active).attempt;
      try {
        final observation = await _repository.getMcpAuthenticationStatus(target: _target, attemptId: attempt.attemptId);
        if (_state is _Retired) return;
        if (observation case V2McpAuthenticationTerminal(:final event)) {
          _finish(event: event);
          return;
        }
        if (observation is V2McpAuthenticationUnknown) {
          Log.w("[opencode-v2] Unknown MCP attempt status for ${_target.integrationId}; retaining native ownership");
        }
      } on Object catch (error, stackTrace) {
        if (_state is _Retired) return;
        Log.w(
          "[opencode-v2] MCP status failed for ${_target.integrationId}; retaining native ownership",
          error,
          stackTrace,
        );
      }
      await Future.any<void>([Future<void>.delayed(_pollInterval), done]);
    }
  }

  Future<void> _submitCallback({required Uri callbackUri}) async {
    if (_state case _Active(attempt: V2McpAuthenticationReady(:final challenge))) {
      return await _repository.submitMcpCallback(challenge: challenge, callbackUri: callbackUri);
    }
    throw PluginMcpAuthenticationCallbackRejectedException(innerError: StateError("No active OpenCode MCP challenge"));
  }

  Future<void> _cancel() => _cancellation ??= _cancelNative().whenComplete(() => _cancellation = null);

  Future<void> _cancelNative() async {
    if (_state is _Retired) return;
    await _started.future;
    if (_state is _Retired) return;
    if (_state case _Active(:final attempt)) {
      final before = await _repository.getMcpAuthenticationStatus(target: _target, attemptId: attempt.attemptId);
      if (_state is _Retired) return;
      if (before case V2McpAuthenticationTerminal(:final event)) {
        _finish(event: event);
        return;
      }
      await _repository.cancelMcpAuthentication(target: _target, attemptId: attempt.attemptId);
      if (_state is _Retired) return;
      try {
        final observation = await _repository.getMcpAuthenticationStatus(target: _target, attemptId: attempt.attemptId);
        if (_state is _Retired) return;
        if (observation case V2McpAuthenticationTerminal(:final event)) _finish(event: event);
      } on OpenCodeApiException catch (error) {
        if (error.statusCode != 404) rethrow;
        _finish(
          event: switch (attempt) {
            V2McpAuthenticationInvalid(:final cause, :final stackTrace) => _failure(
              error: cause,
              stackTrace: stackTrace,
            ),
            _ => null,
          },
        );
      }
      // Native cancellation is a no-op while a credential is persisting. Keep
      // polling and let its terminal outcome win instead of reporting cancelled.
      await done;
      return;
    }
    throw V2McpAuthenticationException(innerError: StateError("Native start has no acknowledged attempt handle"));
  }

  Future<void> retire() async {
    if (_state is _Retired) return;
    final previous = _state;
    _finish(
      event: _failure(error: StateError("OpenCode runtime stopped"), stackTrace: StackTrace.current),
    );
    if (previous case _Active(:final attempt)) {
      try {
        // This bounds runtime teardown only; it never reports cancellation or
        // releases a live product attempt on an ordinary request deadline.
        await _retireNative(attempt: attempt).timeout(const Duration(seconds: 3));
      } on Object catch (error, stackTrace) {
        Log.w("[opencode-v2] Runtime MCP cleanup uncertain for ${_target.integrationId}", error, stackTrace);
      }
    } else {
      Log.w("[opencode-v2] Runtime retired with uncertain MCP start for ${_target.integrationId}");
    }
  }

  Future<void> _retireNative({required V2McpAuthenticationAttempt attempt}) async {
    await _repository.cancelMcpAuthentication(target: _target, attemptId: attempt.attemptId);
    try {
      final observation = await _repository.getMcpAuthenticationStatus(target: _target, attemptId: attempt.attemptId);
      if (observation is! V2McpAuthenticationTerminal) {
        throw StateError("Native MCP attempt still exists after runtime cleanup");
      }
    } on OpenCodeApiException catch (error) {
      if (error.statusCode != 404) rethrow;
    }
  }

  PluginMcpAuthenticationFailed _failure({required Object error, required StackTrace stackTrace}) =>
      PluginMcpAuthenticationFailed(
        reason: PluginMcpAuthenticationFailureReason.nativeFailure,
        cause: V2McpAuthenticationException(innerError: error),
        causeStackTrace: stackTrace,
      );

  void _finish({required PluginMcpAuthenticationEvent? event}) {
    if (_state is _Retired) return;
    _state = const _Retired();
    _events.onCancel = null;
    if (event != null) _events.add(event);
    unawaited(_events.close());
    _done.complete();
  }
}

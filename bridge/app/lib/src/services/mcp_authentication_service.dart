import "dart:async";
import "dart:math";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mcp_repository.dart";
import "../repositories/models/mcp_authentication_update.dart";
import "../repositories/random_hex_id.dart";

/// Owns one native attempt across client reconnects. No credentials are stored.
class McpAuthenticationService({required final McpRepository _repository}) {
  final Random _random = Random.secure();
  final StreamController<void> _changes = StreamController.broadcast();
  final StreamController<McpInventoryRequest> _inventoryChanges = StreamController.broadcast();
  _OwnedMcpAuthentication? _current;
  bool _disposed = false;

  Stream<void> get changes => _changes.stream;
  Stream<McpInventoryRequest> get inventoryChanges => _inventoryChanges.stream;
  McpAuthenticationResult get current => McpAuthenticationStateResult(
    state: _current?.state ?? const McpAuthenticationIdle(),
  );

  Future<McpAuthenticationResult> start({required McpAuthenticationStartRequest request}) async {
    if (_disposed) return const McpAuthenticationUnavailable(reason: McpAuthenticationUnavailableReason.pluginInactive);
    if (_current case final owner? when !owner.done.isCompleted) return const McpAuthenticationBusy();
    final owner = _OwnedMcpAuthentication(
      initialAttempt: McpAuthenticationAttempt(
        attemptId: generateRandomHexId(secureRandom: _random, prefix: "mcp_", byteLength: 16),
        pluginId: request.pluginId,
        target: request.target,
        cancellation: McpAuthenticationCancellation.unknown,
      ),
    );
    _current = owner;
    _changes.add(null);
    _repository
        .authenticate(request: request)
        .listen(
          (update) => _receive(owner: owner, update: update),
          onError: (Object error, StackTrace stackTrace) => _failed(owner: owner, error: error, stackTrace: stackTrace),
          onDone: () => _settled(owner: owner),
        )
        .addTo(owner.subscriptions);
    return await owner.ready.future;
  }

  Future<McpAuthenticationResult> continueAuthentication({required McpAuthenticationContinueRequest request}) async {
    final owner = _active(attemptId: request.attemptId);
    if (owner == null) {
      return const McpAuthenticationUnavailable(reason: McpAuthenticationUnavailableReason.attemptNotFound);
    }
    final challenge = owner.state;
    if (challenge is! McpAuthenticationCallbackChallenge) {
      return const McpAuthenticationUnavailable(reason: McpAuthenticationUnavailableReason.callbackRejected);
    }
    await _repository.validateAuthenticationTarget(attempt: owner.attempt);
    // Archive validation awaits catalog I/O; native settlement can occur meanwhile.
    if (owner.done.isCompleted || owner.state is! McpAuthenticationCallbackChallenge) {
      return const McpAuthenticationUnavailable(reason: McpAuthenticationUnavailableReason.attemptNotFound);
    }
    final Uri callbackUri;
    try {
      callbackUri = Uri.parse(request.callbackUrl);
    } on FormatException {
      return const McpAuthenticationUnavailable(reason: McpAuthenticationUnavailableReason.callbackRejected);
    }
    final operation = (owner.native as _RunningMcpAuthentication).operation;
    _publish(
      owner: owner,
      state: McpAuthenticationSettling(attempt: owner.attempt),
    );
    try {
      await operation.submitCallback(callbackUri: callbackUri);
    } on PluginMcpAuthenticationCallbackRejectedException {
      if (!owner.done.isCompleted && !owner.cancelRequested) {
        _publish(owner: owner, state: challenge);
      }
      return const McpAuthenticationUnavailable(reason: McpAuthenticationUnavailableReason.callbackRejected);
    } on Object catch (error, stackTrace) {
      Log.w(
        "MCP callback submission failed for ${owner.attempt.attemptId}",
        McpAuthenticationCallbackException(innerError: error),
        stackTrace,
      );
      // Delivery is uncertain; keep waiting for native truth rather than retrying.
    }
    return McpAuthenticationStateResult(state: owner.state);
  }

  Future<McpAuthenticationResult> cancel({required McpAuthenticationCancelRequest request}) async {
    final owner = _active(attemptId: request.attemptId);
    if (owner == null) {
      return const McpAuthenticationUnavailable(reason: McpAuthenticationUnavailableReason.attemptNotFound);
    }
    if (owner.cancelRequested) return McpAuthenticationStateResult(state: owner.state);
    if (owner.native is _PreparingMcpAuthentication) {
      owner.cancelRequested = true;
      try {
        await owner.dispose();
        _publish(
          owner: owner,
          state: McpAuthenticationCancelled(attempt: owner.attempt),
        );
      } on Object catch (error, stackTrace) {
        _publish(
          owner: owner,
          state: McpAuthenticationFailed(attempt: owner.attempt, reason: McpAuthenticationFailureReason.nativeFailure),
        );
        Error.throwWithStackTrace(McpAuthenticationCancellationException(innerError: error), stackTrace);
      } finally {
        if (!owner.ready.isCompleted) owner.ready.complete(McpAuthenticationStateResult(state: owner.state));
        if (!owner.done.isCompleted) owner.done.complete();
      }
      return McpAuthenticationStateResult(state: owner.state);
    }
    switch ((owner.native as _RunningMcpAuthentication).operation) {
      case PluginMcpNativeSettlementAuthentication():
        return const McpAuthenticationUnavailable(
          reason: McpAuthenticationUnavailableReason.nativeCancellationUnavailable,
        );
      case PluginMcpCancelableAuthentication(:final cancel):
        owner.cancelRequested = true;
        _publish(
          owner: owner,
          state: McpAuthenticationSettling(attempt: owner.attempt),
        );
        try {
          await cancel();
          await owner.dispose();
        } on Object catch (error, stackTrace) {
          final failure = McpAuthenticationFailed(
            attempt: owner.attempt,
            reason: McpAuthenticationFailureReason.nativeFailure,
          );
          owner.terminal = failure;
          _publish(owner: owner, state: failure);
          Error.throwWithStackTrace(McpAuthenticationCancellationException(innerError: error), stackTrace);
        }
        if (!owner.done.isCompleted) {
          _publish(
            owner: owner,
            state: owner.terminal ?? McpAuthenticationCancelled(attempt: owner.attempt),
          );
          owner.done.complete();
        }
        return McpAuthenticationStateResult(state: owner.state);
    }
  }

  _OwnedMcpAuthentication? _active({required String attemptId}) {
    final owner = _current;
    return owner != null && owner.attempt.attemptId == attemptId && !owner.done.isCompleted ? owner : null;
  }

  void _receive({required _OwnedMcpAuthentication owner, required McpAuthenticationUpdate update}) {
    switch (update) {
      case McpAuthenticationStarted(:final operation, :final activate):
        final attempt = McpAuthenticationAttempt(
          attemptId: owner.attempt.attemptId,
          pluginId: owner.attempt.pluginId,
          target: owner.attempt.target,
          cancellation: switch (operation) {
            PluginMcpCancelableAuthentication() => McpAuthenticationCancellation.cancelable,
            PluginMcpNativeSettlementAuthentication() => McpAuthenticationCancellation.nativeSettlement,
          },
        );
        owner.native = _RunningMcpAuthentication(attempt: attempt, operation: operation);
        _publish(
          owner: owner,
          state: McpAuthenticationStarting(attempt: owner.attempt),
        );
        owner.ready.complete(McpAuthenticationStateResult(state: owner.state));
        activate();
      case McpAuthenticationNativeEvent(:final event):
        switch (event) {
          case PluginMcpAuthenticationChallenge(:final authorizationUri, :final expectedCallbackUri):
            final challenge = McpAuthenticationCallbackChallenge(
              attempt: owner.attempt,
              authorizationUrl: authorizationUri.toString(),
              expectedCallbackUrl: expectedCallbackUri.toString(),
            );
            if (!owner.cancelRequested) _publish(owner: owner, state: challenge);
          case PluginMcpAuthenticationCompleted():
            owner.terminal = McpAuthenticationCompleted(attempt: owner.attempt);
          case PluginMcpAuthenticationFailed(:final reason, :final cause, :final causeStackTrace):
            Log.w(
              "MCP authentication failed for ${owner.attempt.pluginId} on ${owner.attempt.target}",
              cause,
              causeStackTrace,
            );
            owner.terminal = McpAuthenticationFailed(
              attempt: owner.attempt,
              reason: switch (reason) {
                PluginMcpAuthenticationFailureReason.nativeFailure => McpAuthenticationFailureReason.nativeFailure,
                PluginMcpAuthenticationFailureReason.declined => McpAuthenticationFailureReason.declined,
                PluginMcpAuthenticationFailureReason.expired => McpAuthenticationFailureReason.expired,
                PluginMcpAuthenticationFailureReason.nativeTrustRequired =>
                  McpAuthenticationFailureReason.nativeTrustRequired,
              },
            );
        }
    }
  }

  void _failed({required _OwnedMcpAuthentication owner, required Object error, required StackTrace stackTrace}) {
    if (!owner.ready.isCompleted) {
      switch (error) {
        case McpAuthenticationUnavailableException(:final reason):
          owner.ready.complete(McpAuthenticationUnavailable(reason: reason));
        case PluginMcpAuthenticationUnavailableException(:final reason):
          owner.ready.complete(
            McpAuthenticationUnavailable(
              reason: switch (reason) {
                PluginMcpAuthenticationUnavailableReason.unsupportedScope =>
                  McpAuthenticationUnavailableReason.unsupportedScope,
                PluginMcpAuthenticationUnavailableReason.liveSessionRequired =>
                  McpAuthenticationUnavailableReason.liveSessionRequired,
                PluginMcpAuthenticationUnavailableReason.targetNotFound =>
                  McpAuthenticationUnavailableReason.targetNotFound,
                PluginMcpAuthenticationUnavailableReason.nativeConfigurationRequired =>
                  McpAuthenticationUnavailableReason.nativeConfigurationRequired,
                PluginMcpAuthenticationUnavailableReason.notSupported =>
                  McpAuthenticationUnavailableReason.notSupported,
                PluginMcpAuthenticationUnavailableReason.notImplemented =>
                  McpAuthenticationUnavailableReason.notImplemented,
              },
            ),
          );
        default:
          owner.ready.completeError(error, stackTrace);
      }
      return;
    }
    if (error case McpAuthenticationCleanupException(
      :final innerError,
      :final innerStackTrace,
      :final cleanupError,
      :final cleanupStackTrace,
    )) {
      Log.w("MCP authentication stream failed for ${owner.attempt.pluginId}", innerError, innerStackTrace);
      Log.w("MCP authentication cleanup failed for ${owner.attempt.pluginId}", cleanupError, cleanupStackTrace);
    } else {
      Log.w("MCP authentication stream failed for ${owner.attempt.pluginId}", error, stackTrace);
    }
    owner.terminal = McpAuthenticationFailed(
      attempt: owner.attempt,
      reason: McpAuthenticationFailureReason.nativeFailure,
    );
  }

  void _settled({required _OwnedMcpAuthentication owner}) {
    if (owner.native is _PreparingMcpAuthentication) {
      if (!owner.ready.isCompleted) {
        owner.ready.complete(
          const McpAuthenticationUnavailable(reason: McpAuthenticationUnavailableReason.pluginInactive),
        );
      }
      _current = null;
      _changes.add(null);
    } else {
      final terminal =
          owner.terminal ??
          (owner.cancelRequested
              ? McpAuthenticationCancelled(attempt: owner.attempt)
              : McpAuthenticationFailed(attempt: owner.attempt, reason: McpAuthenticationFailureReason.interrupted));
      _publish(owner: owner, state: terminal);
      if (terminal is McpAuthenticationCompleted) {
        final scope = switch ((owner.native as _RunningMcpAuthentication).operation.effectScope) {
          PluginMcpActionEffectScope.session || PluginMcpActionEffectScope.project => owner.attempt.target.scope,
          PluginMcpActionEffectScope.harness => const McpHarnessScope(),
        };
        _inventoryChanges.add(McpInventoryRequest(pluginId: owner.attempt.pluginId, scope: scope));
      }
    }
    owner.done.complete();
  }

  void _publish({required _OwnedMcpAuthentication owner, required McpAuthenticationState state}) {
    owner.state = state;
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    _disposed = true;
    final owner = _current;
    try {
      if (owner != null && !owner.done.isCompleted) await owner.dispose();
    } finally {
      if (owner != null && !owner.done.isCompleted) {
        owner.state = McpAuthenticationFailed(
          attempt: owner.attempt,
          reason: McpAuthenticationFailureReason.interrupted,
        );
        if (!owner.ready.isCompleted) owner.ready.complete(McpAuthenticationStateResult(state: owner.state));
        owner.done.complete();
      }
      await Future.wait([_changes.close(), _inventoryChanges.close()]);
    }
  }
}

class _OwnedMcpAuthentication({required McpAuthenticationAttempt initialAttempt}) {
  this {
    native = _PreparingMcpAuthentication(attempt: initialAttempt);
    state = McpAuthenticationStarting(attempt: initialAttempt);
  }
  late _NativeMcpAuthentication native;
  McpAuthenticationAttempt get attempt => native.attempt;
  late McpAuthenticationState state;
  final Completer<McpAuthenticationResult> ready = Completer();
  final Completer<void> done = Completer();
  final CompositeSubscription subscriptions = CompositeSubscription();
  McpAuthenticationState? terminal;
  bool cancelRequested = false;

  Future<void> dispose() => subscriptions.cancel();
}

sealed class const _NativeMcpAuthentication({required final McpAuthenticationAttempt attempt});

final class const _PreparingMcpAuthentication({required super.attempt}) extends _NativeMcpAuthentication;

final class const _RunningMcpAuthentication({
  required super.attempt,
  required final PluginMcpAuthenticationOperation operation,
}) extends _NativeMcpAuthentication;

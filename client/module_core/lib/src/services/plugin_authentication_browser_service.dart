import "dart:async";
import "dart:convert";
import "dart:math";

import "package:injectable/injectable.dart";

import "../foundation/io/plugin_authentication_loopback_server.dart";
import "../foundation/platform/plugin_authentication_browser.dart";
import "../repositories/models/plugin_management_result.dart";

const pluginAuthenticationCallbackScheme = "com.sesori.auth";
const _callbackHost = "complete";
const _operationLifetime = Duration(minutes: 5);

enum PluginAuthenticationBrowserPhase() {
  opening,
  waiting,
}

sealed class const PluginAuthenticationBrowserFlowResult();

final class const PluginAuthenticationBrowserDirect() extends PluginAuthenticationBrowserFlowResult;

final class const PluginAuthenticationBrowserCaptured({required final Uri callbackUri})
    extends PluginAuthenticationBrowserFlowResult;

final class const PluginAuthenticationBrowserFlowCancelled() extends PluginAuthenticationBrowserFlowResult;

final class const PluginAuthenticationBrowserFlowFailed({
  // The owner retains this cause for diagnostics. Presentation must never expose it.
  // ignore: prefer_specific_type
  required final Object innerError,
  required final StackTrace stackTrace,
  required final bool retryableWithActiveListener,
}) extends PluginAuthenticationBrowserFlowResult;

/// Owns browser mode, callback listener lifetime, nonce validation, retry, and cleanup.
@lazySingleton
class PluginAuthenticationBrowserService({
  required PluginAuthenticationLoopbackServer loopbackServer,
  required PluginAuthenticationBrowser browser,
}) {
  final PluginAuthenticationLoopbackServer _loopbackServer = loopbackServer;
  final PluginAuthenticationBrowser _browser = browser;
  final Random _random = Random.secure();
  _PluginAuthenticationBrowserOperation? _active;

  Future<PluginAuthenticationBrowserFlowResult> authenticate({
    required PluginAuthenticationBrowserChallenge challenge,
    required bool isLocalBridge,
    required bool reuseActiveListener,
    required void Function(PluginAuthenticationBrowserPhase phase) onPhase,
    required void Function(PluginAuthenticationBrowserFlowFailed failure) onDetachedFailure,
  }) async {
    onPhase(PluginAuthenticationBrowserPhase.opening);

    late final _PluginAuthenticationBrowserOperation operation;
    if (reuseActiveListener) {
      final active = _active;
      if (active == null || active.challenge != challenge || active.session == null || active.ended.isCompleted) {
        return PluginAuthenticationBrowserFlowFailed(
          innerError: StateError("Authentication callback listener is no longer active"),
          stackTrace: StackTrace.current,
          retryableWithActiveListener: false,
        );
      }
      operation = active
        ..detachedAfterRetryableFailure = false
        ..onDetachedFailure = onDetachedFailure;
    } else {
      final previous = _active;
      operation = _PluginAuthenticationBrowserOperation(
        challenge: challenge,
        bounceUri: isLocalBridge
            ? null
            : Uri(
                scheme: pluginAuthenticationCallbackScheme,
                host: _callbackHost,
                pathSegments: [
                  base64UrlEncode(List<int>.generate(24, (_) => _random.nextInt(256))).replaceAll("=", ""),
                ],
              ),
        onDetachedFailure: onDetachedFailure,
      );
      _active = operation;
      operation.timer = Timer(_operationLifetime, () => _expire(operation: operation));
      if (previous != null) {
        final previousResult = await _finish(
          operation: previous,
          result: const PluginAuthenticationBrowserFlowCancelled(),
        );
        if (operation.ended.isCompleted) return await operation.ended.future;
        if (previousResult is PluginAuthenticationBrowserFlowFailed) {
          return await _finish(operation: operation, result: previousResult);
        }
      }
    }

    if (isLocalBridge) {
      final result = await _openDirect(operation: operation);
      return await _finish(operation: operation, result: result);
    }

    if (operation.session == null) {
      final bindResult = await _bind(operation: operation);
      if (bindResult != null) return bindResult;
    }

    final result = await _openRemote(operation: operation, onPhase: onPhase);
    if (result case PluginAuthenticationBrowserFlowFailed(retryableWithActiveListener: true)) {
      operation.detachedAfterRetryableFailure = true;
      return result;
    }
    return await _finish(operation: operation, result: result);
  }

  Future<PluginAuthenticationBrowserFlowResult?> _bind({
    required _PluginAuthenticationBrowserOperation operation,
  }) async {
    final binding = _loopbackServer
        .bind(
          expectedCallbackUri: operation.challenge.expectedCallbackUri,
          bounceUri: _browser.returnsToApp ? operation.bounceUri : null,
        )
        .then<_BindingResult>(
          (session) => _BindingSucceeded(session: session),
          onError: (Object error, StackTrace stackTrace) => _BindingFailed(error: error, stackTrace: stackTrace),
        );
    final outcome = await Future.any<_BindingWaitResult>([
      binding.then<_BindingWaitResult>((result) => _BindingCompleted(result: result)),
      operation.ended.future.then<_BindingWaitResult>((result) => _BindingOperationEnded(result: result)),
    ]);
    switch (outcome) {
      case _BindingOperationEnded(:final result):
        unawaited(_closeLateBinding(binding: binding, operation: operation));
        return result;
      case _BindingCompleted(result: _BindingFailed(:final error, :final stackTrace)):
        final failure = PluginAuthenticationBrowserFlowFailed(
          innerError: error,
          stackTrace: stackTrace,
          retryableWithActiveListener: false,
        );
        return await _finish(operation: operation, result: failure);
      case _BindingCompleted(result: _BindingSucceeded(:final session)):
        if (!identical(_active, operation) || operation.ended.isCompleted) {
          final result = operation.ended.isCompleted
              ? await operation.ended.future
              : const PluginAuthenticationBrowserFlowCancelled();
          final closeFailure = await _closeSession(session: session);
          return closeFailure ?? result;
        }
        operation.session = session;
        return null;
    }
  }

  Future<void> _closeLateBinding({
    required Future<_BindingResult> binding,
    required _PluginAuthenticationBrowserOperation operation,
  }) async {
    final result = await binding;
    if (result case _BindingSucceeded(:final session)) {
      final failure = await _closeSession(session: session);
      if (failure != null) operation.onDetachedFailure(failure);
    }
  }

  Future<PluginAuthenticationBrowserFlowResult> _openDirect({
    required _PluginAuthenticationBrowserOperation operation,
  }) async {
    final browser = _browser
        .open(
          authorizationUri: operation.challenge.authorizationUri,
          callbackScheme: pluginAuthenticationCallbackScheme,
        )
        .then<PluginAuthenticationBrowserResult>(
          (result) => result,
          onError: (Object error, StackTrace stackTrace) =>
              PluginAuthenticationBrowserFailed(innerError: error, stackTrace: stackTrace),
        );
    final outcome = await _waitFor(future: browser, operation: operation);
    return switch (outcome) {
      _OperationEnded(:final result) => result,
      _OperationValue(value: PluginAuthenticationBrowserOpened() || PluginAuthenticationBrowserReturned()) =>
        const PluginAuthenticationBrowserDirect(),
      _OperationValue(value: PluginAuthenticationBrowserCancelled()) =>
        const PluginAuthenticationBrowserFlowCancelled(),
      _OperationValue(value: PluginAuthenticationBrowserFailed(:final innerError, :final stackTrace)) =>
        PluginAuthenticationBrowserFlowFailed(
          innerError: innerError,
          stackTrace: stackTrace,
          retryableWithActiveListener: false,
        ),
    };
  }

  Future<PluginAuthenticationBrowserFlowResult> _openRemote({
    required _PluginAuthenticationBrowserOperation operation,
    required void Function(PluginAuthenticationBrowserPhase phase) onPhase,
  }) async {
    final session = operation.session;
    if (session == null) {
      return PluginAuthenticationBrowserFlowFailed(
        innerError: StateError("Authentication callback listener is unavailable"),
        stackTrace: StackTrace.current,
        retryableWithActiveListener: false,
      );
    }
    final callback = session.callback.then<_CallbackResult>(
      (uri) => _CallbackReceived(uri: uri),
      onError: (Object error, StackTrace stackTrace) => _CallbackFailed(error: error, stackTrace: stackTrace),
    );
    final browser = _browser
        .open(
          authorizationUri: operation.challenge.authorizationUri,
          callbackScheme: pluginAuthenticationCallbackScheme,
        )
        .then<PluginAuthenticationBrowserResult>(
          (result) => result,
          onError: (Object error, StackTrace stackTrace) =>
              PluginAuthenticationBrowserFailed(innerError: error, stackTrace: stackTrace),
        );
    onPhase(PluginAuthenticationBrowserPhase.waiting);

    final browserOutcome = await _waitFor(future: browser, operation: operation);
    final PluginAuthenticationBrowserResult browserResult;
    switch (browserOutcome) {
      case _OperationEnded(:final result):
        return result;
      case _OperationValue(:final value):
        browserResult = value;
    }
    if (_browser.returnsToApp) {
      switch (browserResult) {
        case PluginAuthenticationBrowserCancelled():
          return const PluginAuthenticationBrowserFlowCancelled();
        case PluginAuthenticationBrowserReturned(:final callbackUri) when callbackUri == operation.bounceUri:
          break;
        case PluginAuthenticationBrowserFailed(:final innerError, :final stackTrace):
          return PluginAuthenticationBrowserFlowFailed(
            innerError: innerError,
            stackTrace: stackTrace,
            retryableWithActiveListener: true,
          );
        case PluginAuthenticationBrowserOpened() || PluginAuthenticationBrowserReturned():
          return PluginAuthenticationBrowserFlowFailed(
            innerError: StateError("Native authentication returned an invalid callback"),
            stackTrace: StackTrace.current,
            retryableWithActiveListener: false,
          );
      }
    } else {
      switch (browserResult) {
        case PluginAuthenticationBrowserOpened():
          break;
        case PluginAuthenticationBrowserCancelled():
          return const PluginAuthenticationBrowserFlowCancelled();
        case PluginAuthenticationBrowserFailed(:final innerError, :final stackTrace):
          return PluginAuthenticationBrowserFlowFailed(
            innerError: innerError,
            stackTrace: stackTrace,
            retryableWithActiveListener: true,
          );
        case PluginAuthenticationBrowserReturned():
          return PluginAuthenticationBrowserFlowFailed(
            innerError: StateError("External browser returned an unexpected callback"),
            stackTrace: StackTrace.current,
            retryableWithActiveListener: false,
          );
      }
    }

    final callbackOutcome = await _waitFor(future: callback, operation: operation);
    return switch (callbackOutcome) {
      _OperationEnded(:final result) => result,
      _OperationValue(value: _CallbackReceived(:final uri)) when uri != null => PluginAuthenticationBrowserCaptured(
        callbackUri: uri,
      ),
      _OperationValue(value: _CallbackReceived()) => PluginAuthenticationBrowserFlowFailed(
        innerError: StateError("Authentication callback listener closed before receiving a callback"),
        stackTrace: StackTrace.current,
        retryableWithActiveListener: false,
      ),
      _OperationValue(value: _CallbackFailed(:final error, :final stackTrace)) => PluginAuthenticationBrowserFlowFailed(
        innerError: error,
        stackTrace: stackTrace,
        retryableWithActiveListener: false,
      ),
    };
  }

  Future<_OperationWaitResult<T>> _waitFor<T>({
    required Future<T> future,
    required _PluginAuthenticationBrowserOperation operation,
  }) => Future.any([
    future.then<_OperationWaitResult<T>>((value) => _OperationValue(value: value)),
    operation.ended.future.then<_OperationWaitResult<T>>((result) => _OperationEnded(result: result)),
  ]);

  Future<PluginAuthenticationBrowserFlowFailed?> cancelActive() async {
    final operation = _active;
    if (operation == null) return null;
    final result = await _finish(
      operation: operation,
      result: const PluginAuthenticationBrowserFlowCancelled(),
    );
    return result is PluginAuthenticationBrowserFlowFailed ? result : null;
  }

  Future<void> _expire({required _PluginAuthenticationBrowserOperation operation}) async {
    if (!identical(_active, operation) || operation.ended.isCompleted) return;
    final result = await _finish(
      operation: operation,
      result: PluginAuthenticationBrowserFlowFailed(
        innerError: TimeoutException("Authentication browser operation timed out", _operationLifetime),
        stackTrace: StackTrace.current,
        retryableWithActiveListener: false,
      ),
    );
    if (operation.detachedAfterRetryableFailure && result is PluginAuthenticationBrowserFlowFailed) {
      operation.onDetachedFailure(result);
    }
  }

  Future<PluginAuthenticationBrowserFlowResult> _finish({
    required _PluginAuthenticationBrowserOperation operation,
    required PluginAuthenticationBrowserFlowResult result,
  }) {
    final finishing = operation.finishing;
    if (finishing != null) return finishing;
    final future = _finishOnce(operation: operation, result: result);
    operation.finishing = future;
    return future;
  }

  Future<PluginAuthenticationBrowserFlowResult> _finishOnce({
    required _PluginAuthenticationBrowserOperation operation,
    required PluginAuthenticationBrowserFlowResult result,
  }) async {
    if (identical(_active, operation)) _active = null;
    operation.timer?.cancel();
    final session = operation.session;
    final closeFailure = session == null ? null : await _closeSession(session: session);
    final finalResult = closeFailure ?? result;
    if (!operation.ended.isCompleted) operation.ended.complete(finalResult);
    return finalResult;
  }

  Future<PluginAuthenticationBrowserFlowFailed?> _closeSession({
    required PluginAuthenticationLoopbackSession session,
  }) async {
    try {
      await session.close();
      return null;
    } on Object catch (error, stackTrace) {
      return PluginAuthenticationBrowserFlowFailed(
        innerError: error,
        stackTrace: stackTrace,
        retryableWithActiveListener: false,
      );
    }
  }
}

class _PluginAuthenticationBrowserOperation({
  required final PluginAuthenticationBrowserChallenge challenge,
  required final Uri? bounceUri,
  required void Function(PluginAuthenticationBrowserFlowFailed failure) onDetachedFailure,
}) {
  PluginAuthenticationLoopbackSession? session;
  Timer? timer;
  final Completer<PluginAuthenticationBrowserFlowResult> ended = Completer();
  Future<PluginAuthenticationBrowserFlowResult>? finishing;
  bool detachedAfterRetryableFailure = false;
  void Function(PluginAuthenticationBrowserFlowFailed failure) onDetachedFailure = onDetachedFailure;
}

sealed class _BindingResult();

final class _BindingSucceeded({required final PluginAuthenticationLoopbackSession session}) extends _BindingResult;

final class _BindingFailed({required final Object error, required final StackTrace stackTrace}) extends _BindingResult;

sealed class _BindingWaitResult();

final class _BindingCompleted({required final _BindingResult result}) extends _BindingWaitResult;

final class _BindingOperationEnded({required final PluginAuthenticationBrowserFlowResult result})
    extends _BindingWaitResult;

sealed class _OperationWaitResult<T>();

final class _OperationValue<T>({required final T value}) extends _OperationWaitResult<T>;

final class _OperationEnded<T>({required final PluginAuthenticationBrowserFlowResult result})
    extends _OperationWaitResult<T>;

sealed class _CallbackResult();

final class _CallbackReceived({required final Uri? uri}) extends _CallbackResult;

final class _CallbackFailed({required final Object error, required final StackTrace stackTrace})
    extends _CallbackResult;

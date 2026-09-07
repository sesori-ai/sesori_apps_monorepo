import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_authentication_budget.dart";
import "../models/antigravity_authentication.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../services/antigravity_authentication_service.dart";
import "../services/antigravity_profile_service.dart";
import "../services/antigravity_runtime_service.dart";

/// One attempt. Closing its event stream means all owned work has settled;
/// the bridge lifecycle service then owns terminal setup reinspection.
class AntigravityAuthenticationOperation({
  required final AntigravityProfileService _profile,
  required final AntigravityRuntimeService _runtime,
  required final AntigravityAuthenticationService _authentication,
  required final PlatformTarget _target,
  required final String? _explicitServerPath,
  required final String? _managedServerPath,
  required Map<String, String> hostEnvironment,
  required final StartAbortSignal _aborted,
  required final Duration _timeout,
}) {
  final Map<String, String> _hostEnvironment = Map.unmodifiable(hostEnvironment);
  final StartAbortController _abort = StartAbortController();
  final Completer<void> _settled = Completer<void>();
  final Completer<AsyncError> _failure = Completer<AsyncError>();
  _RedirectState _redirect = const _AwaitingAuthorization();
  late final AntigravityAuthenticationBudget _budget = AntigravityAuthenticationBudget(
    timeout: _timeout,
    abortSignal: _abort.signal,
  );
  late final StreamController<PluginAuthenticationBrowserEvent> _events = StreamController(
    onListen: () => unawaited(_run()),
    onCancel: () {
      _abort.abort();
      return _settled.future;
    },
  );

  late final PluginAuthenticationBrowserOperation operation = PluginAuthenticationBrowserOperation(
    events: _events.stream,
    submitRedirect: _submitRedirect,
  );

  Future<void> _run() async {
    StreamSubscription<AntigravityAuthorization>? authorizations;
    Future<void>? authenticationWork;

    try {
      if (_aborted.isAborted) _abort.abort();
      unawaited(_aborted.whenAborted.then((_) => _abort.abort()));
      final prepared = await _profile.prepare(budget: _budget, hostEnvironment: _hostEnvironment);
      _budget.remaining;
      final resolution = await _runtime.resolve(
        explicitServerPath: _explicitServerPath,
        managedServerPath: _managedServerPath,
        pathEnvironment: prepared.environment,
        probeEnvironment: prepared.environment,
        target: _target,
        timeout: _budget.remaining,
        abortSignal: _abort.signal,
      );
      _budget.remaining;
      if (resolution is! AntigravityRuntimeSelected) {
        final details = switch (resolution) {
          AntigravityRuntimeSelected(:final source, :final pair) => "${source.name}: selected ${pair.serverPath}",
          AntigravityRuntimeMissing(:final source, :final component) => "${source.name}: missing ${component.name}",
          AntigravityRuntimePairRejected(:final source, :final component, :final issue) =>
            "${source.name}: ${component.name} rejected (${issue.name})",
          AntigravityRuntimeContractRejected(:final source, :final pair, :final violations) =>
            "${source.name}: ${pair.serverPath} with ${pair.harnessPath}; "
                "contract violations: ${violations.map((violation) => violation.name).join(', ')}",
          AntigravityRuntimeUnsupported(:final target) => "unsupported target ${target.os.name}/${target.arch.name}",
          AntigravityRuntimeStorageFailed(:final source) => "${source.name}: runtime inspection failed",
          AntigravityRuntimeProbeFailed(:final source, :final pair) =>
            "${source.name}: probe failed for ${pair.serverPath}",
        };
        final failure = AntigravityAuthenticationException(
          message: "No usable Antigravity runtime for login ($details)",
          cause: resolution,
        );
        if (resolution case AntigravityRuntimeStorageFailed(:final cause, :final stackTrace)) {
          Log.w("[antigravity] authentication runtime inspection failed", cause, stackTrace);
        } else if (resolution case AntigravityRuntimeProbeFailed(:final pair, :final cause, :final stackTrace)) {
          Log.w("[antigravity] authentication runtime probe failed for ${pair.serverPath}", cause, stackTrace);
        }
        throw failure;
      }
      authorizations = _authentication.authorizations.listen(
        (authorization) => _offerAuthorization(authorization: authorization),
        onError: (Object error, StackTrace stackTrace) => _fail(error: error, stackTrace: stackTrace),
      );
      authenticationWork = _authentication
          .authenticate(
            pair: resolution.pair,
            environment: prepared.environment,
            budget: _budget,
          )
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) => _fail(error: error, stackTrace: stackTrace),
          );
      await Future.any<void>([
        authenticationWork,
        _failure.future.then<void>((failure) => Error.throwWithStackTrace(failure.error, failure.stackTrace)),
      ]);
      final redirect = _redirect;
      _redirect = const _RedirectClosed();
      if (redirect case _RedirectSubmitted(:final settled)) await settled;
      _budget.remaining;
    } on Object catch (error, stackTrace) {
      _fail(error: error, stackTrace: stackTrace);
    } finally {
      final redirect = _redirect;
      _redirect = const _RedirectClosed();
      // On failure _fail has already aborted both boundary operations.
      await authenticationWork;
      if (redirect case _RedirectSubmitted(:final settled)) await settled;
      await authorizations?.cancel();
      try {
        await _authentication.dispose();
        if (!_failure.isCompleted) _budget.remaining;
      } on Object catch (error, stackTrace) {
        if (!_failure.isCompleted) {
          _fail(error: error, stackTrace: stackTrace);
        } else {
          Log.w("[antigravity] authentication cleanup failed", error, stackTrace);
        }
      }
      if (_failure.isCompleted) {
        final failure = await _failure.future;
        _events.addError(failure.error, failure.stackTrace);
      } else {
        _events.add(const PluginAuthenticationCompleted());
      }
      _abort.abort();
      // Do not await delivery: onCancel itself waits for cleanup completion.
      unawaited(_events.close());
      _settled.complete();
    }
  }

  void _offerAuthorization({required AntigravityAuthorization authorization}) {
    if (_abort.isAborted || _redirect is _RedirectClosed) return;
    if (_redirect is! _AwaitingAuthorization) {
      _fail(
        error: const AntigravityAuthenticationException(message: "Login issued multiple challenges", cause: null),
        stackTrace: StackTrace.current,
      );
      return;
    }
    _redirect = _RedirectOffered(authorization: authorization);
    _events.add(
      PluginAuthenticationBrowserChallenge(
        authorizationUri: authorization.authorizationUri,
        expectedCallbackUri: authorization.callbackUri,
      ),
    );
  }

  Future<void> _submitRedirect({required Uri redirectUri}) async {
    _budget.remaining;
    final current = _redirect;
    if (current is! _RedirectOffered) {
      throw const AntigravityAuthenticationException(message: "Login is not accepting a callback", cause: null);
    }
    final settled = Completer<void>();
    _redirect = _RedirectSubmitted(settled: settled.future);
    try {
      await _authentication.submitRedirect(
        authorization: current.authorization,
        redirectUri: redirectUri,
        budget: _budget,
      );
      _budget.remaining;
    } on Object catch (error, stackTrace) {
      _fail(error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      settled.complete();
    }
  }

  void _fail({required Object error, required StackTrace stackTrace}) {
    if (!_failure.isCompleted) _failure.complete(AsyncError(error, stackTrace));
    _abort.abort();
  }
}

sealed class const _RedirectState();
final class const _AwaitingAuthorization() extends _RedirectState;
final class const _RedirectOffered({required final AntigravityAuthorization authorization}) extends _RedirectState;
final class const _RedirectSubmitted({required final Future<void> settled}) extends _RedirectState;
final class const _RedirectClosed() extends _RedirectState;

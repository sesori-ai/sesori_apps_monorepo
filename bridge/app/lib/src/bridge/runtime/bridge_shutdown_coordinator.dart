import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginStartAbortedException, StartAbortSignal;

enum BridgeShutdownPhase() {
  signal,
  drain,
  pluginDispose,
  lifecycle,
  shared,
}

class BridgeShutdownCoordinator({
    required final StartAbortSignal _startAbortSignal,
    int Function()? backstopExitCode,
    void Function(int code)? exitProcess,
    final Future<void> Function()? _emergencyDisposal,
  }) {

  static int _alwaysZero() => 0;
  static const Duration _backstopSlack = Duration(seconds: 10);

  /// How long the backstop waits for [emergencyDisposal] before exiting.
  /// Sized above the plugins' agent-process kill escalation so it can run to
  /// completion — ACP's teardown SIGTERMs the agent, waits up to 5s, then
  /// SIGKILLs; a smaller cap would exit the bridge before the SIGKILL and
  /// orphan an agent that ignores SIGTERM, the exact outcome this hook
  /// exists to prevent.
  static const Duration _emergencyDisposalCap = Duration(seconds: 6);

  final int Function() _backstopExitCode = backstopExitCode ?? _alwaysZero;
  final void Function(int code) _exitProcess = exitProcess ?? io.exit;
  final Map<BridgeShutdownPhase, List<_ShutdownAction>> _actions = {
    for (final phase in BridgeShutdownPhase.values) phase: <_ShutdownAction>[],
  };
  Future<void>? _activeShutdown;

  void add({required FutureOr<void> Function() disposable}) {
    addPhase(phase: BridgeShutdownPhase.shared, action: disposable);
  }

  void addOrdered({required Future<void> Function() action, required Duration budget}) {
    addPhase(phase: BridgeShutdownPhase.lifecycle, action: action, budget: budget);
  }

  void addPhase({
    required BridgeShutdownPhase phase,
    required FutureOr<void> Function() action,
    Duration budget = Duration.zero,
  }) {
    _actions[phase]!.add(_ShutdownAction(action: action, budget: budget));
  }

  Future<void> shutdown() => _activeShutdown ??= _shutdownInternal();

  Future<void> _shutdownInternal() async {
    final shutdownBudget = _actions.values.fold(Duration.zero, (total, actions) {
      final phaseBudget = actions.fold(
        Duration.zero,
        (longest, action) => action.budget > longest ? action.budget : longest,
      );
      return total + phaseBudget;
    });
    final totalSw = Stopwatch()..start();
    final backstop = Timer(shutdownBudget + _backstopSlack, () {
      Log.e("Failed to finish gracefully after ${totalSw.elapsedMilliseconds}ms - forcing exit");
      unawaited(_emergencyDisposalThenExit());
    });
    Object? firstError;
    StackTrace? firstStackTrace;

    try {
      for (final phase in BridgeShutdownPhase.values) {
        final actions = _actions[phase]!;
        final futures = <Future<void>>[];
        for (final action in actions) {
          try {
            final result = action.action();
            futures.add(Future<void>.value(result));
          } on Object catch (error, stackTrace) {
            if (!_isExpected(error)) {
              firstError ??= error;
              firstStackTrace ??= stackTrace;
            }
          }
        }
        for (final future in futures) {
          try {
            await future;
          } on Object catch (error, stackTrace) {
            if (!_isExpected(error)) {
              firstError ??= error;
              firstStackTrace ??= stackTrace;
            }
          }
        }
      }
    } finally {
      backstop.cancel();
      Log.d("[shutdown] coordinator complete (${totalSw.elapsedMilliseconds}ms total)");
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  bool _isExpected(Object error) {
    return error is PluginStartAbortedException && _startAbortSignal.isAborted;
  }

  /// Last-resort disposal before the backstop exits the process: kicks the
  /// registered emergency disposal (e.g. stopping plugin backend processes so
  /// they are not orphaned by a forced exit) and bounds it with
  /// [_emergencyDisposalCap]. Never throws — the exit happens regardless.
  Future<void> _emergencyDisposalThenExit() async {
    try {
      await _emergencyDisposal?.call().timeout(_emergencyDisposalCap);
    } on Object catch (error, stackTrace) {
      Log.w("[shutdown] emergency disposal failed; exiting anyway", error, stackTrace);
    } finally {
      _exitProcess(_backstopExitCode());
    }
  }
}

class const _ShutdownAction({required final FutureOr<void> Function() action, required final Duration budget});

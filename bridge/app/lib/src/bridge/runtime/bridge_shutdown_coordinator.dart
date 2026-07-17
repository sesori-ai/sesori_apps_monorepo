import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginStartAbortedException;

enum BridgeShutdownPhase {
  signal,
  earlyPluginDispose,
  drain,
  lifecycle,
  shared,
}

class BridgeShutdownCoordinator {
  BridgeShutdownCoordinator({
    int Function()? backstopExitCode,
    void Function(int code)? exitProcess,
    bool Function()? startWasAborted,
  }) : _backstopExitCode = backstopExitCode ?? _alwaysZero,
       _exitProcess = exitProcess ?? io.exit,
       _startWasAborted = startWasAborted ?? _alwaysFalse;

  static int _alwaysZero() => 0;
  static bool _alwaysFalse() => false;
  static const Duration _backstopSlack = Duration(seconds: 10);

  final int Function() _backstopExitCode;
  final void Function(int code) _exitProcess;
  final bool Function() _startWasAborted;
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
    final longestBudget = _actions.values
        .expand((actions) => actions)
        .fold(Duration.zero, (longest, action) => action.budget > longest ? action.budget : longest);
    final totalSw = Stopwatch()..start();
    final backstop = Timer(longestBudget + _backstopSlack, () {
      Log.e("Failed to finish gracefully after ${totalSw.elapsedMilliseconds}ms - forcing exit");
      _exitProcess(_backstopExitCode());
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
    return error is PluginStartAbortedException && _startWasAborted();
  }
}

class _ShutdownAction {
  const _ShutdownAction({required this.action, required this.budget});

  final FutureOr<void> Function() action;
  final Duration budget;
}

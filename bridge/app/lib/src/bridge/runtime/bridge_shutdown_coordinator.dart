import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Coordinates bridge shutdown in two phases under one process-wide backstop:
///
/// 1. **Ordered phase** — steps registered with [addOrdered] run
///    sequentially, in registration order. The plugin's `shutdown(budget)`
///    runs here so api teardown and the owned-runtime stop finish before
///    anything else is torn down (previously they raced the parallel phase).
/// 2. **Parallel phase** — disposables registered with [add] run
///    concurrently, as before.
///
/// The backstop timer is armed *before* the ordered phase — there is no
/// window with no timer running — and is sized as the sum of the ordered
/// budgets plus [_backstopSlack] for the parallel phase. When it fires, the
/// process exits with [backstopExitCode]: a hung shutdown after a terminal
/// plugin failure must not exit 0.
///
/// A *throwing* ordered step does not block later steps or the parallel
/// phase, but [shutdown] rethrows the first such error once both phases ran
/// — a failed plugin stop must surface loudly (non-zero exit), exactly as it
/// did when it was a parallel disposable.
class BridgeShutdownCoordinator {
  BridgeShutdownCoordinator({
    int Function()? backstopExitCode,
    void Function(int code)? exitProcess,
  }) : _backstopExitCode = backstopExitCode ?? _alwaysZero,
       _exitProcess = exitProcess ?? io.exit;

  static int _alwaysZero() => 0;

  static const Duration _backstopSlack = Duration(seconds: 10);

  final int Function() _backstopExitCode;
  final void Function(int code) _exitProcess;
  final List<FutureOr<void> Function()> _disposables = <FutureOr<void> Function()>[];
  final List<({Future<void> Function() action, Duration budget})> _orderedSteps =
      <({Future<void> Function() action, Duration budget})>[];
  Future<void>? _activeShutdown;

  void add({required FutureOr<void> Function() disposable}) {
    _disposables.add(disposable);
  }

  /// Registers an ordered shutdown step that runs before the parallel phase.
  ///
  /// [budget] is the step's soft deadline; it extends the backstop rather
  /// than being enforced per-step (the step itself is expected to degrade to
  /// forceful termination within its budget).
  void addOrdered({required Future<void> Function() action, required Duration budget}) {
    _orderedSteps.add((action: action, budget: budget));
  }

  Future<void> shutdown() {
    return _activeShutdown ??= _shutdownInternal();
  }

  Future<void> _shutdownInternal() async {
    final orderedBudget = _orderedSteps.fold(Duration.zero, (total, step) => total + step.budget);
    final backstop = Timer(orderedBudget + _backstopSlack, () {
      Log.e("Failed to finish gracefully");
      _exitProcess(_backstopExitCode());
    });

    try {
      Object? firstOrderedError;
      StackTrace? firstOrderedStackTrace;
      for (final step in _orderedSteps) {
        try {
          await step.action();
        } catch (error, stackTrace) {
          Log.e("Ordered shutdown step failed: $error");
          firstOrderedError ??= error;
          firstOrderedStackTrace ??= stackTrace;
        }
      }
      // Future.sync (not Future.value(disposable())): a synchronously
      // throwing disposable must become a failed future, not abort the lazy
      // map iteration inside Future.wait and skip the disposables after it.
      await Future.wait(
        _disposables.map(Future.sync),
      );
      if (firstOrderedError != null) {
        Error.throwWithStackTrace(firstOrderedError, firstOrderedStackTrace!);
      }
    } finally {
      backstop.cancel();
    }
  }
}

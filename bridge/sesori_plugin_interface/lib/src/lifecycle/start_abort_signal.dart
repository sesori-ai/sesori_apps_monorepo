import "dart:async";

/// Read side of the cooperative start-abort signal.
///
/// The bridge hands this to a plugin through `PluginHost.startAborted`. A
/// well-behaved `start()` checks [isAborted] at every phase boundary (after
/// stale cleanup, after port selection, after spawn, after each health
/// probe) and, when aborted, rolls back everything acquired so far and then
/// settles by throwing `PluginStartAbortedException`.
///
/// This signal exists because the bridge holds its cross-instance startup
/// mutex until `start()` settles — there is deliberately no abandoning
/// `Future.timeout` around `start()`, since an abandoned start would keep
/// mutating shared state (ownership records, child processes) while a new
/// bridge believes the lock is free.
abstract class StartAbortSignal {
  /// A signal that never aborts, for callers that don't support aborting.
  static final StartAbortSignal never = _NeverAbortedSignal();

  /// Whether the start has been aborted. Cheap to poll.
  bool get isAborted;

  /// Completes when the start is aborted; never completes otherwise.
  ///
  /// Only await this raced against other work (e.g. `Future.any`) — on the
  /// happy path it never completes.
  Future<void> get whenAborted;
}

/// Write side of the start-abort signal, owned by the bridge.
class StartAbortController {
  StartAbortController() : _signal = _CompleterAbortSignal();

  final _CompleterAbortSignal _signal;

  /// The read side to hand to the plugin.
  StartAbortSignal get signal => _signal;

  /// Whether [abort] has been called.
  bool get isAborted => _signal.isAborted;

  /// Aborts the start. Idempotent.
  void abort() {
    if (_signal.isAborted) {
      return;
    }
    _signal._completer.complete();
  }
}

class _CompleterAbortSignal implements StartAbortSignal {
  final Completer<void> _completer = Completer<void>();

  @override
  bool get isAborted => _completer.isCompleted;

  @override
  Future<void> get whenAborted => _completer.future;
}

class _NeverAbortedSignal implements StartAbortSignal {
  @override
  bool get isAborted => false;

  // A fresh, unrooted future per call: it still never completes, but once
  // the caller's references drop, the future and its listeners (which
  // capture the whole start context) become collectible — a single rooted
  // completer would pin every listener for the process lifetime.
  @override
  Future<void> get whenAborted => Completer<void>().future;
}

import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show ParallelLock;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/normalized_bridge_event.dart";
import "../repositories/session_interruption_repository.dart";
import "../services/session_event_dispatcher.dart";

/// Keeps a durable running row for every session with a turn in flight, so
/// the next bridge run can tell which turns this one stopped during.
///
/// A busy status marks the session running and an idle clears it. Once
/// [beginShutdown] runs, idles no longer clear rows: the interrupts a
/// shutdown sends end turns the bridge is cutting off, so a stop by signal
/// leaves the rows exactly as a killed process does.
class RunningTurnListener({
  required final Stream<NormalizedSourcedBridgeEvent> _source,
  required final SessionInterruptionRepository _interruptions,
  required final Clock _clock,
}) {
  StreamSubscription<NormalizedSourcedBridgeEvent>? _subscription;

  /// One lane, so a session's mark and clear land in the order they happened.
  final ParallelLock _writes = ParallelLock(maxParallelOperations: 1);
  Future<void>? _disposeFuture;
  bool _shuttingDown = false;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (sourced) => _observe(event: sourced.event),
      // Source errors are surfaced by the dispatcher's own consumers; a failed
      // event carries no status to record.
      onError: (Object _) {},
    );
  }

  /// Stops idles from clearing rows. A shutdown signal action registered
  /// before the shutdown interrupts, so it runs before any idle they cause.
  void beginShutdown() {
    _shuttingDown = true;
  }

  void _observe({required NormalizedBridgeEvent event}) {
    switch (event) {
      case NormalizedTerminalHandoff(:final payload):
        _observe(event: payload);
      case NormalizedStatusEvent(:final sessionId, status: SessionStatusBusy() || SessionStatusRetry()):
        _write(
          sessionId: sessionId,
          write: () => _interruptions.markRunning(sessionId: sessionId, at: _clock.now()),
        );
      case NormalizedStatusEvent(:final sessionId, status: SessionStatusIdle()):
      case NormalizedOtherEvent(event: BridgeSseSessionIdle(sessionID: final sessionId)):
        if (_shuttingDown) return;
        _write(
          sessionId: sessionId,
          write: () => _interruptions.clearRunning(sessionId: sessionId),
        );
      case NormalizedMessageEvent() ||
          NormalizedQueuedPromptsEvent() ||
          NormalizedQuotaInterruptionEvent() ||
          NormalizedOtherEvent():
        return;
    }
  }

  void _write({required String sessionId, required Future<void> Function() write}) {
    unawaited(
      _writes.use(operation: write).catchError((Object error, StackTrace stackTrace) {
        // A lost mark only misses an interruption; a lost clear can show one
        // for a turn that ended. Neither blocks the session.
        Log.w("Could not record the running turn of session $sessionId", error, stackTrace);
      }),
    );
  }

  /// Memoized so a second caller joins the same drain instead of returning
  /// while writes are still running.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _writes.idle;
  }
}

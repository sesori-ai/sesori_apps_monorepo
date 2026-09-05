import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/models/normalized_bridge_event.dart";
import "../services/chat_history_service.dart";
import "../services/session_event_dispatcher.dart";

/// Persists finalized message events into the chat history store.
///
/// It consumes events after [SessionEventDispatcher] normalization, so ids are
/// already translated to bridge session ids and stale generations are fenced.
/// Streaming deltas are ignored: only full snapshots are stored.
///
/// Finalized *part* snapshots are deliberately absent here: the Orchestrator
/// captures them, because a part carrying bridge-owned images must be stored
/// before its live event can advertise a reference. Capturing ordinary parts
/// here as well would let a later part enter the session queue ahead of an
/// awaited image part and reverse persisted part order.
class ChatHistoryListener({
  required final Stream<NormalizedSourcedBridgeEvent> _source,
  required final ChatHistoryService _chatHistoryService,
}) {
  StreamSubscription<NormalizedSourcedBridgeEvent>? _subscription;
  final PendingOperations _pendingCaptures = PendingOperations();
  Future<void>? _disposeFuture;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      // Keeps the write observable to [dispose], so shutdown does not close
      // the database out from under a finalized event still being persisted.
      (sourced) => unawaited(
        _pendingCaptures.track(
          operation: _capture(pluginId: sourced.pluginId, event: sourced.event),
        ),
      ),
      // Source errors are surfaced by the dispatcher's own consumers; capture
      // simply has nothing to store for a failed event.
      onError: (Object _) {},
    );
  }

  Future<void> _capture({required String pluginId, required NormalizedBridgeEvent event}) {
    return switch (event) {
      NormalizedOtherEvent(event: BridgeSseServerConnected()) => _chatHistoryService.invalidatePluginHistory(
        pluginId: pluginId,
      ),
      NormalizedMessageEvent(:final message) => _chatHistoryService.captureMessage(
        sessionId: message.sessionID,
        message: message,
      ),
      // A forced-stop handoff carries no finalized message, and a status
      // change stores nothing.
      NormalizedOtherEvent() || NormalizedStatusEvent() || NormalizedTerminalHandoff() => Future<void>.value(),
    };
  }

  /// Memoized so a second caller joins the same drain instead of returning
  /// while finalized writes are still running.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    // Capture never throws (failures are logged and drop the synced marker),
    // so waiting cannot fail teardown.
    await _pendingCaptures.drain();
  }
}

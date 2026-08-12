import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../bridge/services/chat_history_service.dart";
import "../bridge/services/session_event_dispatcher.dart";

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
class ChatHistoryListener {
  final Stream<NormalizedSourcedBridgeEvent> _source;
  final ChatHistoryService _chatHistoryService;
  StreamSubscription<NormalizedSourcedBridgeEvent>? _subscription;
  final Set<Future<void>> _pendingCaptures = {};
  Future<void>? _disposeFuture;
  bool _disposed = false;

  ChatHistoryListener({
    required Stream<NormalizedSourcedBridgeEvent> source,
    required ChatHistoryService chatHistoryService,
  }) : _source = source,
       _chatHistoryService = chatHistoryService;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (sourced) => _track(
        capture: _capture(pluginId: sourced.pluginId, event: sourced.event),
      ),
      // Source errors are surfaced by the dispatcher's own consumers; capture
      // simply has nothing to store for a failed event.
      onError: (Object _) {},
    );
  }

  /// Keeps the write observable to [dispose], so shutdown does not close the
  /// database out from under a finalized event still being persisted.
  void _track({required Future<void> capture}) {
    _pendingCaptures.add(capture);
    unawaited(capture.whenComplete(() => _pendingCaptures.remove(capture)));
  }

  Future<void> _capture({required String pluginId, required BridgeSseEvent event}) {
    return switch (event) {
      BridgeSseServerConnected() => _chatHistoryService.invalidatePluginHistory(pluginId: pluginId),
      BridgeSseMessageUpdated(:final info) => _captureMessage(info: info),
      BridgeSseMessageRemoved(:final sessionID, :final messageID) => _chatHistoryService.captureMessageRemoved(
        sessionId: sessionID,
        messageId: messageID,
      ),
      _ => Future<void>.value(),
    };
  }

  Future<void> _captureMessage({required Map<String, dynamic> info}) async {
    final Message message;
    try {
      message = Message.fromJson(info);
    } on Object catch (error, stackTrace) {
      Log.w("Ignoring an undecodable message event; it will not be stored", error, stackTrace);
      return;
    }
    await _chatHistoryService.captureMessage(sessionId: message.sessionID, message: message);
  }

  /// Memoized so a second caller joins the same drain instead of returning
  /// while finalized writes are still running.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    // Capture never throws (failures are logged and drop the synced marker),
    // so waiting cannot fail teardown.
    await Future.wait(_pendingCaptures.toList(growable: false));
  }
}

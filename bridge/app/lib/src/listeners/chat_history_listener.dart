import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../bridge/plugin_to_shared_mapping.dart";
import "../bridge/services/chat_history_service.dart";
import "../bridge/services/session_event_dispatcher.dart";

/// Persists finalized message events into the chat history store.
///
/// It consumes events after [SessionEventDispatcher] normalization, so ids are
/// already translated to bridge session ids and stale generations are fenced.
/// Streaming deltas are ignored: only full snapshots are stored.
class ChatHistoryListener {
  final Stream<NormalizedSourcedBridgeEvent> _source;
  final ChatHistoryService _chatHistoryService;
  StreamSubscription<NormalizedSourcedBridgeEvent>? _subscription;
  bool _disposed = false;

  ChatHistoryListener({
    required Stream<NormalizedSourcedBridgeEvent> source,
    required ChatHistoryService chatHistoryService,
  }) : _source = source,
       _chatHistoryService = chatHistoryService;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (sourced) => unawaited(_capture(event: sourced.event)),
      // Source errors are surfaced by the dispatcher's own consumers; capture
      // simply has nothing to store for a failed event.
      onError: (Object _) {},
    );
  }

  Future<void> _capture({required BridgeSseEvent event}) {
    return switch (event) {
      BridgeSseMessageUpdated(:final info) => _captureMessage(info: info),
      BridgeSseMessagePartUpdated(:final part) => _chatHistoryService.capturePart(
        sessionId: part.sessionID,
        part: part.toShared(sessionId: part.sessionID),
      ),
      BridgeSseMessageRemoved(:final sessionID, :final messageID) => _chatHistoryService.captureMessageRemoved(
        sessionId: sessionID,
        messageId: messageID,
      ),
      BridgeSseMessagePartRemoved(:final sessionID, :final messageID, :final partID) => _chatHistoryService
          .capturePartRemoved(sessionId: sessionID, messageId: messageID, partId: partID),
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

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
  }
}

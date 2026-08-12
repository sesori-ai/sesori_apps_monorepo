import "package:sesori_shared/sesori_shared.dart";

/// Retains the latest part event until its owning message envelope arrives.
class DeferredPartEventBuffer() {
  final Map<String, List<_DeferredPartEvent>> _eventsByMessageId = {};
  int _latestSequence = 0;

  Iterable<String> get messageIds => _eventsByMessageId.keys;
  int get latestSequence => _latestSequence;

  void deferUpdated({required MessagePart part}) {
    _upsert(
      messageId: part.messageID,
      partId: part.id,
      event: SesoriMessagePartUpdated(part: part),
    );
  }

  void deferRemoved({required String sessionId, required String messageId, required String partId}) {
    _upsert(
      messageId: messageId,
      partId: partId,
      event: SesoriMessagePartRemoved(
        sessionID: sessionId,
        messageID: messageId,
        partID: partId,
      ),
    );
  }

  List<SesoriSessionEvent> takeForMessage({required String messageId}) =>
      _eventsByMessageId.remove(messageId)?.map((item) => item.event).toList() ?? const [];

  void removeMessage({required String messageId}) => _eventsByMessageId.remove(messageId);

  /// Discards events superseded by messages in an applied snapshot.
  void discardForMessagesThrough({required Iterable<String> messageIds, required int sequence}) {
    for (final messageId in messageIds) {
      final events = _eventsByMessageId[messageId];
      if (events == null) continue;
      events.removeWhere((event) => event.sequence <= sequence);
      if (events.isEmpty) _eventsByMessageId.remove(messageId);
    }
  }

  void clear() => _eventsByMessageId.clear();

  void _upsert({required String messageId, required String partId, required SesoriSessionEvent event}) {
    final events = _eventsByMessageId.putIfAbsent(messageId, () => []);
    final index = events.indexWhere((item) => item.partId == partId);
    final deferred = _DeferredPartEvent(
      partId: partId,
      event: event,
      sequence: ++_latestSequence,
    );
    if (index >= 0) {
      events[index] = deferred;
    } else {
      events.add(deferred);
    }
  }
}

final class const _DeferredPartEvent({required this.partId, required this.event, required this.sequence}) {
  final String partId;
  final SesoriSessionEvent event;
  final int sequence;
}

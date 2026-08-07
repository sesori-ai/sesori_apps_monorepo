import "dart:async";

import "../repositories/chat_history_repository.dart";

/// The single writer of the chat history store.
///
/// Every mutation runs through a per-session queue so writes for one session
/// never interleave, while unrelated sessions stay independent.
class ChatHistoryService {
  ChatHistoryService({required ChatHistoryRepository chatHistoryRepository})
    : _chatHistoryRepository = chatHistoryRepository;

  final ChatHistoryRepository _chatHistoryRepository;
  final Map<String, Future<void>> _writeQueues = {};

  /// Removes the session's stored transcript and attachment bytes.
  Future<void> purgeSessionHistory({required String sessionId}) {
    return _enqueue(
      sessionId: sessionId,
      write: () => _chatHistoryRepository.purgeSession(sessionId: sessionId),
    );
  }

  Future<void> _enqueue({required String sessionId, required Future<void> Function() write}) {
    final pending = _writeQueues[sessionId] ?? Future<void>.value();
    final result = pending.then((_) => write());
    // The queue continues from a swallowed copy so one failed write does not
    // poison later writes for the session; the caller still sees the error.
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _writeQueues[sessionId] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_writeQueues[sessionId], tail)) _writeQueues.remove(sessionId);
      }),
    );
    return result;
  }
}

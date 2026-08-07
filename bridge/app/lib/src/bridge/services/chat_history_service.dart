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
    return purgeSessionsHistory(sessionIds: [sessionId]);
  }

  /// Removes stored history for a whole session family in one pass.
  ///
  /// The batch is serialized behind every listed session's write queue, so no
  /// concurrent capture can re-create rows the purge is removing.
  Future<void> purgeSessionsHistory({required List<String> sessionIds}) {
    if (sessionIds.isEmpty) return Future<void>.value();
    return _enqueueAll(
      sessionIds: sessionIds,
      write: () => _chatHistoryRepository.purgeSessions(sessionIds: sessionIds),
    );
  }

  /// Runs [write] after every listed session's pending writes, and makes it
  /// the new tail for all of them.
  Future<void> _enqueueAll({required List<String> sessionIds, required Future<void> Function() write}) {
    final pending = Future.wait([
      for (final sessionId in sessionIds) _writeQueues[sessionId] ?? Future<void>.value(),
    ]);
    final result = pending.then((_) => write());
    // The queue continues from a swallowed copy so one failed write does not
    // poison later writes for the session; the caller still sees the error.
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    for (final sessionId in sessionIds) {
      _writeQueues[sessionId] = tail;
    }
    unawaited(
      tail.whenComplete(() {
        for (final sessionId in sessionIds) {
          if (identical(_writeQueues[sessionId], tail)) _writeQueues.remove(sessionId);
        }
      }),
    );
    return result;
  }
}

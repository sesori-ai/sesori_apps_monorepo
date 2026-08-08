import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/chat_history_repository.dart";
import "../repositories/session_repository.dart";

/// The single writer of the chat history store.
///
/// Every mutation runs through a per-session queue so writes for one session
/// never interleave, while unrelated sessions stay independent.
class ChatHistoryService {
  ChatHistoryService({
    required ChatHistoryRepository chatHistoryRepository,
    required SessionRepository sessionRepository,
  }) : _chatHistoryRepository = chatHistoryRepository,
       _sessionRepository = sessionRepository;

  final ChatHistoryRepository _chatHistoryRepository;
  final SessionRepository _sessionRepository;
  final Map<String, Future<void>> _writeQueues = {};
  final Map<String, Future<void>> _inFlightBackfills = {};

  /// One page of the session's messages, served from the store whenever it is
  /// known to be current and falling back to the backend otherwise.
  ///
  /// A null [limit] returns the whole transcript, which is what an app that
  /// predates pagination asks for.
  ///
  /// The store is preferred only when a backfill has completed *and* no
  /// backend activity has been observed past the captured watermark, so a
  /// session advanced outside Sesori still reads correctly.
  Future<ChatHistoryPage> getSessionMessages({
    required String sessionId,
    int? limit,
    int? before,
  }) async {
    // Both the freshness decision and the read run inside the session queue,
    // so they observe one state. Deciding outside it would let queued work —
    // an observed import, or a failed capture clearing `syncedAt` — commit
    // between the decision and the read, and the caller would receive a
    // transcript that the store already knew was stale.
    final decided = await _enqueueRead(
      sessionId: sessionId,
      read: () async {
        final state = await _chatHistoryRepository.getSyncState(sessionId: sessionId);
        if (state == null || state.syncedAt == null || state.watermark < state.backendActivityAt) {
          return null;
        }
        return _chatHistoryRepository.getSessionMessages(
          sessionId: sessionId,
          limit: limit,
          before: before,
        );
      },
    );
    if (decided != null) return decided;

    await backfillSession(sessionId: sessionId);
    // The backfill is itself queued, so this read lands after it and after
    // any capture that raced its fetch.
    return _enqueueRead(
      sessionId: sessionId,
      read: () => _chatHistoryRepository.getSessionMessages(
        sessionId: sessionId,
        limit: limit,
        before: before,
      ),
    );
  }

  /// Records backend activity observed outside the live event stream, so a
  /// session advanced through the backend's own CLI is detected as stale.
  ///
  /// Only sessions the store already knows about are tracked; an unknown
  /// session has nothing to be stale against.
  Future<void> observeBackendActivity({required String sessionId, required int activityAt}) {
    return _enqueue(
      sessionId: sessionId,
      write: () async {
        final state = await _chatHistoryRepository.getSyncState(sessionId: sessionId);
        if (state == null) return;
        await _chatHistoryRepository.advanceSyncState(
          sessionId: sessionId,
          watermark: state.watermark,
          backendActivityAt: activityAt,
        );
      },
    );
  }

  /// Records a finalized message from the live event stream.
  Future<void> captureMessage({required String sessionId, required Message message}) {
    return _capture(
      sessionId: sessionId,
      description: "message ${message.id}",
      write: (observedAt) => _chatHistoryRepository.upsertMessage(
        sessionId: sessionId,
        message: message,
        updatedAt: observedAt,
      ),
    );
  }

  /// Records a finalized part snapshot. Streaming deltas are never stored.
  Future<void> capturePart({required String sessionId, required MessagePart part}) {
    return _capture(
      sessionId: sessionId,
      description: "part ${part.id}",
      write: (observedAt) => _chatHistoryRepository.upsertPart(
        sessionId: sessionId,
        part: part,
        updatedAt: observedAt,
      ),
    );
  }

  Future<void> captureMessageRemoved({required String sessionId, required String messageId}) {
    return _capture(
      sessionId: sessionId,
      description: "removal of message $messageId",
      write: (_) => _chatHistoryRepository.deleteMessage(sessionId: sessionId, messageId: messageId),
    );
  }

  Future<void> capturePartRemoved({
    required String sessionId,
    required String messageId,
    required String partId,
  }) {
    return _capture(
      sessionId: sessionId,
      description: "removal of part $partId",
      write: (_) => _chatHistoryRepository.deletePart(
        sessionId: sessionId,
        messageId: messageId,
        partId: partId,
      ),
    );
  }

  /// Fills the store from the backend's own transcript.
  ///
  /// Concurrent callers for the same session await one fetch. Failures
  /// propagate so a cache miss never looks like an empty thread.
  Future<void> backfillSession({required String sessionId}) {
    final inFlight = _inFlightBackfills[sessionId];
    if (inFlight != null) return inFlight;

    final backfill = _backfillSession(sessionId: sessionId);
    _inFlightBackfills[sessionId] = backfill;
    return backfill.whenComplete(() => _inFlightBackfills.remove(sessionId));
  }

  /// Fetches and applies the transcript as one queued unit.
  ///
  /// The fetch is deliberately inside the session's write queue. A transcript
  /// is a snapshot of the backend at fetch time, so any capture that races it
  /// is strictly newer; queueing those captures behind the whole backfill
  /// applies them *after* the snapshot lands, which is the order they actually
  /// happened. Fetching outside the queue instead would let a stale snapshot
  /// overwrite newer updates and resurrect removed messages and parts —
  /// reconciling that afterwards needs per-row tombstones for every
  /// granularity, whereas ordering the two correctly needs none.
  ///
  /// Captures for this session wait for the fetch, but they never block the
  /// event pipeline: the listener dispatches them without awaiting.
  Future<void> _backfillSession({required String sessionId}) {
    return _enqueue(
      sessionId: sessionId,
      write: () async {
        // Read inside the queue too, so it cannot miss a capture that landed
        // between the read and the write.
        final observedBefore = await _chatHistoryRepository.getSyncState(sessionId: sessionId);
        final backendActivityAt = observedBefore?.backendActivityAt ?? 0;
        final messages = await _sessionRepository.getSessionMessages(sessionId: sessionId);
        await _chatHistoryRepository.replaceSessionMessages(
          sessionId: sessionId,
          messages: messages,
          watermark: backendActivityAt,
          backendActivityAt: backendActivityAt,
          syncedAt: DateTime.now().millisecondsSinceEpoch,
        );
      },
    );
  }

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
    // The write runs later, so own the ids rather than trusting the caller's
    // list to stay unchanged until then.
    final owned = List<String>.unmodifiable(sessionIds);
    return _enqueueAll(
      sessionIds: owned,
      write: () => _chatHistoryRepository.purgeSessions(sessionIds: owned),
    );
  }

  Future<Set<String>> getStoredSessionIds() => _chatHistoryRepository.getStoredSessionIds();

  /// Applies one captured event and advances the session's freshness marks.
  ///
  /// A failed capture clears `syncedAt`, so the next read falls back to the
  /// plugin and re-backfills. That self-heals without a retry queue, and it is
  /// why capture never rethrows into the event pipeline.
  Future<void> _capture({
    required String sessionId,
    required String description,
    required Future<void> Function(int observedAt) write,
  }) {
    final observedAt = DateTime.now().millisecondsSinceEpoch;
    return _enqueue(
      sessionId: sessionId,
      write: () async {
        try {
          await write(observedAt);
          await _chatHistoryRepository.advanceSyncState(
            sessionId: sessionId,
            watermark: observedAt,
            backendActivityAt: observedAt,
          );
        } on Object catch (error, stackTrace) {
          Log.w(
            "Failed to capture $description for session $sessionId; "
            "dropping the synced marker so the next read re-backfills",
            error,
            stackTrace,
          );
          await _clearSyncedAtQuietly(sessionId: sessionId);
        }
      },
    );
  }

  Future<void> _clearSyncedAtQuietly({required String sessionId}) async {
    try {
      await _chatHistoryRepository.clearSyncedAt(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      Log.w(
        "Failed to drop the synced marker for session $sessionId; the store "
        "may serve a stale transcript until the next backend activity",
        error,
        stackTrace,
      );
    }
  }

  Future<void> _enqueue({required String sessionId, required Future<void> Function() write}) {
    return _enqueueAll(sessionIds: [sessionId], write: write);
  }

  /// Runs [read] after the session's pending writes and holds the queue for
  /// its duration, so a write enqueued while it runs commits after it rather
  /// than underneath it.
  ///
  /// Reads of one session therefore serialize with each other too. That is
  /// acceptable: a read is a bounded query against a local database, and it
  /// buys a simple guarantee — whatever a read observed is what the caller
  /// receives.
  Future<T> _enqueueRead<T>({required String sessionId, required Future<T> Function() read}) {
    final pending = _writeQueues[sessionId] ?? Future<void>.value();
    final result = pending.then((_) => read());
    final tail = result.then<void>((_) {}, onError: (Object _) {});
    _writeQueues[sessionId] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_writeQueues[sessionId], tail)) _writeQueues.remove(sessionId);
      }),
    );
    return result;
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

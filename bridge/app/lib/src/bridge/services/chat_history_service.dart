import "dart:async";
import "dart:typed_data";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../../api/models/archived_session_file_dto.dart";
import "../repositories/attachment_thumbnail_builder.dart";
import "../repositories/chat_history_repository.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";

sealed class SessionAttachmentResult {
  const SessionAttachmentResult();
}

final class SessionAttachmentFound extends SessionAttachmentResult {
  final Uint8List bytes;
  final String mime;

  const SessionAttachmentFound({required this.bytes, required this.mime});
}

final class SessionAttachmentMissing extends SessionAttachmentResult {
  const SessionAttachmentMissing();
}

final class SessionAttachmentUnsupported extends SessionAttachmentResult {
  const SessionAttachmentUnsupported();
}

final class SessionAttachmentTooLarge extends SessionAttachmentResult {
  const SessionAttachmentTooLarge();
}

/// The single writer of the chat history store.
///
/// Every mutation runs through a per-session queue so writes for one session
/// never interleave, while unrelated sessions stay independent.
class ChatHistoryService {
  ChatHistoryService({
    required ChatHistoryRepository chatHistoryRepository,
    required SessionRepository sessionRepository,
    required AttachmentThumbnailBuilder attachmentThumbnailBuilder,
  }) : _chatHistoryRepository = chatHistoryRepository,
       _sessionRepository = sessionRepository,
       _attachmentThumbnailBuilder = attachmentThumbnailBuilder;

  final ChatHistoryRepository _chatHistoryRepository;
  final SessionRepository _sessionRepository;
  final AttachmentThumbnailBuilder _attachmentThumbnailBuilder;
  final Map<String, Future<void>> _writeQueues = {};
  final Map<String, Future<void>> _inFlightBackfills = {};
  Future<void> _thumbnailGenerationLane = Future.value();

  static const _maxStoredImageBytes = 20 * 1024 * 1024;

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
    // The archive check, the freshness decision, and the read all run inside
    // the session queue, so they observe one state. Deciding outside it would
    // let queued work — an observed import, or a failed capture clearing
    // `syncedAt` — commit in between, and the caller would receive a
    // transcript the store already knew was stale.
    final decided = await _enqueueRead(
      sessionId: sessionId,
      read: () async {
        // The audit file is authoritative only once the session is actually
        // archived. Export writes it *before* the archive flip, so a failed or
        // interrupted archive can leave a file for a session that is still
        // live — serving that would hide newer messages still in the store.
        final stored = await _sessionRepository.getStoredSession(sessionId: sessionId);
        if (stored?.archivedAt != null) {
          final archived = await _chatHistoryRepository.getArchivedSessionMessages(
            sessionId: sessionId,
            limit: limit,
            before: before,
          );
          if (archived != null) return archived;
        }

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

  Future<SessionAttachmentResult> getSessionAttachment({
    required String sessionId,
    required String attachmentId,
    required SessionAttachmentRendition rendition,
  }) {
    return _enqueueRead(
      sessionId: sessionId,
      read: () async {
        if (rendition == SessionAttachmentRendition.thumbnail) {
          final cached = await _chatHistoryRepository.readStoredAttachmentThumbnail(
            sessionId: sessionId,
            attachmentId: attachmentId,
          );
          if (cached != null) {
            return SessionAttachmentFound(bytes: cached.bytes, mime: cached.format.mime);
          }
        }

        final original = await _chatHistoryRepository.readStoredAttachment(
          sessionId: sessionId,
          attachmentId: attachmentId,
        );
        if (original == null) return const SessionAttachmentMissing();
        if (original.bytes.length > _maxStoredImageBytes) {
          return const SessionAttachmentTooLarge();
        }

        if (rendition == SessionAttachmentRendition.original) {
          final mime = _attachmentThumbnailBuilder.detectSupportedMime(bytes: original.bytes);
          return mime == null
              ? const SessionAttachmentUnsupported()
              : SessionAttachmentFound(bytes: original.bytes, mime: mime);
        }

        final built = await _buildThumbnail(bytes: original.bytes);
        return switch (built) {
          AttachmentThumbnailRendered(:final bytes, :final format) =>
            await _chatHistoryRepository.writeStoredAttachmentThumbnail(
                  sessionId: sessionId,
                  attachmentId: attachmentId,
                  location: original.location,
                  format: format,
                  bytes: bytes,
                )
                ? SessionAttachmentFound(bytes: bytes, mime: format.mime)
                : const SessionAttachmentMissing(),
          AttachmentThumbnailUnsupported() => const SessionAttachmentUnsupported(),
          AttachmentThumbnailTooLarge() => const SessionAttachmentTooLarge(),
          AttachmentThumbnailFailed(:final cause, :final stackTrace) => _logThumbnailFailure(
            sessionId: sessionId,
            attachmentId: attachmentId,
            cause: cause,
            stackTrace: stackTrace,
          ),
        };
      },
    );
  }

  Future<AttachmentThumbnailBuildResult> _buildThumbnail({required Uint8List bytes}) {
    final result = _thumbnailGenerationLane.then((_) => _attachmentThumbnailBuilder.build(bytes: bytes));
    _thumbnailGenerationLane = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  SessionAttachmentResult _logThumbnailFailure({
    required String sessionId,
    required String attachmentId,
    required Object cause,
    required StackTrace stackTrace,
  }) {
    Log.w(
      "Failed to generate attachment thumbnail for session $sessionId, attachment $attachmentId",
      cause,
      stackTrace,
    );
    return const SessionAttachmentUnsupported();
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

  /// Marks this plugin's stored live transcripts incomplete across an event
  /// stream gap. Later captures preserve that state because only a full
  /// backfill writes a non-null sync marker.
  Future<void> invalidatePluginHistory({required String pluginId}) async {
    try {
      final results = await Future.wait<Set<String>>([
        _chatHistoryRepository.getStoredSessionIds(),
        _sessionRepository.getStoredSessionIdsForPlugin(pluginId: pluginId),
      ]);
      final sessionIds = results[0].intersection(results[1]).toList(growable: false)..sort();
      if (sessionIds.isEmpty) return;
      await _enqueueAll(
        sessionIds: sessionIds,
        write: () => _chatHistoryRepository.clearSyncedAtForSessions(sessionIds: sessionIds),
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "Failed to invalidate chat history after the $pluginId event stream connected; "
        "stored transcripts may remain stale until a later invalidation succeeds",
        error,
        stackTrace,
      );
    }
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

  /// Writes the session's audit file before it is archived.
  ///
  /// Brings the store current first so the archive captures everything the
  /// backend knows. When the backend cannot be consulted the export proceeds
  /// with whatever the store holds and records that honestly: archiving never
  /// touches backend storage, so its own copy survives, and refusing to
  /// archive would trap the session.
  Future<void> exportSessionHistory({
    required StoredSession session,
    required String? title,
    required String? lastAgent,
    required String? lastAgentModel,
    required int createdAt,
    required int updatedAt,
    required int archivedAt,
  }) async {
    // A completed archive is durable and its live rows are gone, so a repeated
    // request must not overwrite a real transcript with an empty store-only
    // one. Enforced here rather than only at the caller, because this service
    // owns the archive file.
    if (session.archivedAt != null && await _chatHistoryRepository.hasArchive(sessionId: session.id)) {
      Log.i("[archive] session ${session.id} already has an audit file; keeping it");
      return;
    }

    var completeness = ArchivedSessionCompleteness.complete;
    try {
      // Outside the queue because it may fetch from the backend; the freshness
      // it establishes is re-checked inside the queue below.
      await _refreshForExport(sessionId: session.id);
    } on Object catch (error, stackTrace) {
      completeness = ArchivedSessionCompleteness.storeOnly;
      Log.w(
        "[archive] could not bring session ${session.id} current before archiving; "
        "exporting what the store holds (the backend keeps its own copy)",
        error,
        stackTrace,
      );
    }
    await _enqueue(
      sessionId: session.id,
      write: () async {
        // Re-check inside the queue: a capture or an observed import may have
        // landed after the refresh, which would make the rows about to be
        // exported stale. Claiming `complete` then would be a lie, and the
        // post-flip purge would delete the only copy of those messages.
        final state = await _chatHistoryRepository.getSyncState(sessionId: session.id);
        final current = state != null && state.syncedAt != null && state.watermark >= state.backendActivityAt;
        await _chatHistoryRepository.exportSession(
          session: session,
          title: title,
          lastAgent: lastAgent,
          lastAgentModel: lastAgentModel,
          createdAt: createdAt,
          updatedAt: updatedAt,
          archivedAt: archivedAt,
          completeness: current ? completeness : ArchivedSessionCompleteness.storeOnly,
        );
      },
    );
  }

  Future<void> _refreshForExport({required String sessionId}) async {
    final state = await _chatHistoryRepository.getSyncState(sessionId: sessionId);
    if (state != null && state.syncedAt != null && state.watermark >= state.backendActivityAt) return;
    await backfillSession(sessionId: sessionId);
  }

  /// The archived transcript for [sessionId], or null when it has no audit
  /// file.
  Future<ChatHistoryPage?> getArchivedSessionMessages({
    required String sessionId,
    int? limit,
    int? before,
  }) {
    return _chatHistoryRepository.getArchivedSessionMessages(
      sessionId: sessionId,
      limit: limit,
      before: before,
    );
  }

  Future<Set<String>> getArchivedSessionIds() => _chatHistoryRepository.getArchivedSessionIds();

  Future<bool> hasArchive({required String sessionId}) => _chatHistoryRepository.hasArchive(sessionId: sessionId);

  /// Removes the session's stored transcript and attachment bytes.
  Future<void> purgeSessionHistory({required String sessionId, bool includeArchive = false}) {
    return purgeSessionsHistory(sessionIds: [sessionId], includeArchive: includeArchive);
  }

  /// Removes stored history, spill files, and any archive file for a whole
  /// session family in one pass.
  ///
  /// The batch is serialized behind every listed session's write queue, so no
  /// concurrent capture can re-create rows the purge is removing.
  Future<void> purgeSessionsHistory({
    required List<String> sessionIds,
    bool includeArchive = false,
  }) {
    if (sessionIds.isEmpty) return Future<void>.value();
    // The write runs later, so own the ids rather than trusting the caller's
    // list to stay unchanged until then.
    final owned = List<String>.unmodifiable(sessionIds);
    return _enqueueAll(
      sessionIds: owned,
      write: () => _chatHistoryRepository.purgeSessions(sessionIds: owned, includeArchive: includeArchive),
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

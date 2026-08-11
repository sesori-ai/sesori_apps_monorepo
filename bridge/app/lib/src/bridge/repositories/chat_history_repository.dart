import "dart:convert";
import "dart:typed_data";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../../api/archived_session_storage.dart";
import "../../api/attachment_spill_storage.dart";
import "../../api/database/history/chat_history_dao.dart";
import "../../api/database/history/chat_history_database.dart";
import "../../api/models/archived_session_file_dto.dart";
import "models/stored_session.dart";

/// Raised when an audit file was written by a newer bridge than this one.
class ChatHistoryArchiveVersionException implements Exception {
  final String sessionId;
  final int fileVersion;
  final int supportedVersion;

  ChatHistoryArchiveVersionException({
    required this.sessionId,
    required this.fileVersion,
    required this.supportedVersion,
  });

  @override
  String toString() =>
      "archived history for session $sessionId is schema "
      "${fileVersion < 0 ? "unreadable" : "v$fileVersion"}, "
      "which this bridge (v$supportedVersion) cannot read";
}

/// One page of stored history, oldest-first, plus the cursor for the next
/// older page (null when the caller has reached the start of the transcript).
typedef ChatHistoryPage = ({List<MessageWithParts> messages, int? nextCursor});

/// How fresh a session's stored transcript is.
///
/// [syncedAt] is null until a backfill completes, so a row created by live
/// capture never claims to be a complete transcript.
typedef ChatHistorySyncState = ({int watermark, int backendActivityAt, int? syncedAt});

enum StoredAttachmentLocation { live, archived }

typedef StoredAttachmentBytes = ({Uint8List bytes, StoredAttachmentLocation location});
typedef StoredAttachmentThumbnail = ({
  Uint8List bytes,
  AttachmentThumbnailFormat format,
});

/// Owns the stored representation of chat history: database rows, their JSON
/// payloads, and the attachment spill files those payloads reference.
class ChatHistoryRepository {
  ChatHistoryRepository({
    required ChatHistoryDao chatHistoryDao,
    required AttachmentSpillStorage attachmentSpillStorage,
    required ArchivedSessionStorage archivedSessionStorage,
    required AttachmentSpillStorage archivedAttachmentStorage,
  }) : _chatHistoryDao = chatHistoryDao,
       _attachmentSpillStorage = attachmentSpillStorage,
       _archivedSessionStorage = archivedSessionStorage,
       _archivedAttachmentStorage = archivedAttachmentStorage;

  static const _archiveSchemaVersion = 1;

  final ChatHistoryDao _chatHistoryDao;
  final AttachmentSpillStorage _attachmentSpillStorage;
  final ArchivedSessionStorage _archivedSessionStorage;
  final AttachmentSpillStorage _archivedAttachmentStorage;

  Future<StoredAttachmentBytes?> readStoredAttachment({
    required String sessionId,
    required String attachmentId,
  }) async {
    if (!AttachmentSpillStorage.isContentAddress(digest: attachmentId)) return null;
    final live = await _attachmentSpillStorage.read(sessionId: sessionId, digest: attachmentId);
    if (live != null) return (bytes: live, location: StoredAttachmentLocation.live);
    final archived = await _archivedAttachmentStorage.read(sessionId: sessionId, digest: attachmentId);
    return archived == null ? null : (bytes: archived, location: StoredAttachmentLocation.archived);
  }

  Future<StoredAttachmentThumbnail?> readStoredAttachmentThumbnail({
    required String sessionId,
    required String attachmentId,
  }) async {
    if (!AttachmentSpillStorage.isContentAddress(digest: attachmentId)) return null;
    final live = await _attachmentSpillStorage.readThumbnail(sessionId: sessionId, digest: attachmentId);
    if (live != null) {
      return (bytes: live.bytes, format: live.format);
    }
    final archived = await _archivedAttachmentStorage.readThumbnail(sessionId: sessionId, digest: attachmentId);
    return archived == null ? null : (bytes: archived.bytes, format: archived.format);
  }

  Future<bool> writeStoredAttachmentThumbnail({
    required String sessionId,
    required String attachmentId,
    required StoredAttachmentLocation location,
    required AttachmentThumbnailFormat format,
    required Uint8List bytes,
  }) {
    if (!AttachmentSpillStorage.isContentAddress(digest: attachmentId)) return Future.value(false);
    final storage = switch (location) {
      StoredAttachmentLocation.live => _attachmentSpillStorage,
      StoredAttachmentLocation.archived => _archivedAttachmentStorage,
    };
    return storage.writeThumbnail(
      sessionId: sessionId,
      digest: attachmentId,
      format: format,
      bytes: bytes,
    );
  }

  Future<ChatHistorySyncState?> getSyncState({required String sessionId}) async {
    final row = await _chatHistoryDao.getSyncState(sessionId: sessionId);
    return row == null
        ? null
        : (watermark: row.watermark, backendActivityAt: row.backendActivityAt, syncedAt: row.syncedAt);
  }

  /// The session's stored transcript, oldest first, with attachments
  /// rehydrated from their spill files.
  Future<ChatHistoryPage> getSessionMessages({
    required String sessionId,
    int? limit,
    int? before,
  }) async {
    final messageRows = await _chatHistoryDao.getMessages(
      sessionId: sessionId,
      limit: limit,
      before: before,
    );
    final partRows = await _chatHistoryDao.getParts(
      sessionId: sessionId,
      messageIds: limit == null ? null : [for (final row in messageRows) row.messageId],
    );
    final partsByMessage = <String, List<MessagePart>>{};
    for (final row in partRows) {
      partsByMessage
          .putIfAbsent(row.messageId, () => [])
          .add(await _rehydratePart(sessionId: sessionId, partJson: row.partJson));
    }
    final messages = [
      for (final row in messageRows)
        MessageWithParts(
          info: Message.fromJson(jsonDecodeMap(row.infoJson)),
          parts: partsByMessage[row.messageId] ?? const [],
        ),
    ];
    // A full page implies there may be more; a short one proves there is not,
    // which avoids an extra count query on every read. An empty page is never
    // "full": there is nothing older to point a cursor at.
    final hasOlder = limit != null && messageRows.isNotEmpty && messageRows.length == limit;
    return (
      messages: messages,
      nextCursor: hasOlder ? messageRows.first.seq : null,
    );
  }

  /// Stores one message, appending it after the current maximum when new.
  Future<void> upsertMessage({
    required String sessionId,
    required Message message,
    required int updatedAt,
  }) async {
    final existingSeq = await _chatHistoryDao.getMessageSeq(sessionId: sessionId, messageId: message.id);
    final seq = existingSeq ?? (await _chatHistoryDao.getMaxSeq(sessionId: sessionId) ?? 0) + 1;
    await _chatHistoryDao.upsertMessage(
      row: HistoryMessagesTableData(
        sessionId: sessionId,
        messageId: message.id,
        seq: seq,
        infoJson: jsonEncode(message.toJson()),
        updatedAt: updatedAt,
      ),
    );
  }

  /// Stores one part, spilling any inline attachment bytes to disk first.
  Future<void> upsertPart({
    required String sessionId,
    required MessagePart part,
    required int updatedAt,
  }) async {
    final existingOrder = await _chatHistoryDao.getPartOrderIndex(
      sessionId: sessionId,
      messageId: part.messageID,
      partId: part.id,
    );
    final orderIndex =
        existingOrder ??
        (await _chatHistoryDao.getMaxPartOrderIndex(sessionId: sessionId, messageId: part.messageID) ?? -1) + 1;
    await _chatHistoryDao.upsertPart(
      row: HistoryPartsTableData(
        sessionId: sessionId,
        messageId: part.messageID,
        partId: part.id,
        orderIndex: orderIndex,
        partJson: await _encodePart(sessionId: sessionId, part: part),
        updatedAt: updatedAt,
      ),
    );
  }

  Future<void> deleteMessage({required String sessionId, required String messageId}) {
    return _chatHistoryDao.deleteMessage(sessionId: sessionId, messageId: messageId);
  }

  Future<void> deletePart({
    required String sessionId,
    required String messageId,
    required String partId,
  }) {
    return _chatHistoryDao.deletePart(sessionId: sessionId, messageId: messageId, partId: partId);
  }

  /// Replaces the session's transcript with [messages], numbering them in
  /// transcript order.
  ///
  /// Rows the transcript does not contain — live events newer than the fetch —
  /// are kept above the imported maximum, preserving their relative order, so
  /// no captured message is lost to a backfill that raced it.
  Future<void> replaceSessionMessages({
    required String sessionId,
    required List<MessageWithParts> messages,
    required int watermark,
    required int backendActivityAt,
    required int syncedAt,
  }) async {
    final importedIds = {for (final message in messages) message.info.id};
    final storedRows = await _chatHistoryDao.getMessages(sessionId: sessionId);
    final retained = [
      for (final row in storedRows)
        if (!importedIds.contains(row.messageId)) row,
    ];

    final messageRows = <HistoryMessagesTableData>[];
    final partRows = <HistoryPartsTableData>[];
    var seq = 0;
    for (final message in messages) {
      seq++;
      messageRows.add(
        HistoryMessagesTableData(
          sessionId: sessionId,
          messageId: message.info.id,
          seq: seq,
          infoJson: jsonEncode(message.info.toJson()),
          updatedAt: syncedAt,
        ),
      );
      for (var index = 0; index < message.parts.length; index++) {
        final part = message.parts[index];
        partRows.add(
          HistoryPartsTableData(
            sessionId: sessionId,
            messageId: message.info.id,
            partId: part.id,
            orderIndex: index,
            partJson: await _encodePart(sessionId: sessionId, part: part),
            updatedAt: syncedAt,
          ),
        );
      }
    }
    for (final row in retained..sort((left, right) => left.seq.compareTo(right.seq))) {
      seq++;
      messageRows.add(row.copyWith(seq: seq));
    }

    await _chatHistoryDao.replaceSessionRows(
      sessionId: sessionId,
      messages: messageRows,
      parts: partRows,
      retainedMessageIds: {for (final row in retained) row.messageId},
      watermark: watermark,
      backendActivityAt: backendActivityAt,
      syncedAt: syncedAt,
    );
  }

  Future<void> advanceSyncState({
    required String sessionId,
    required int watermark,
    required int backendActivityAt,
  }) {
    return _chatHistoryDao.advanceSyncState(
      sessionId: sessionId,
      watermark: watermark,
      backendActivityAt: backendActivityAt,
    );
  }

  Future<void> clearSyncedAt({required String sessionId}) {
    return _chatHistoryDao.clearSyncedAt(sessionId: sessionId);
  }

  Future<Set<String>> getStoredSessionIds() => _chatHistoryDao.getStoredSessionIds();

  /// Writes the session's audit file and copies its attachment bytes beside
  /// it, leaving the live store untouched.
  ///
  /// The spill files are copied rather than moved so a crash before the
  /// archive flip leaves the still-active session's attachments intact; the
  /// live copies are removed later by the post-flip purge.
  Future<void> exportSession({
    required StoredSession session,
    required String? title,
    required int createdAt,
    required int updatedAt,
    required int archivedAt,
    required ArchivedSessionCompleteness completeness,
    required String? lastAgent,
    required String? lastAgentModel,
  }) async {
    final messageRows = await _chatHistoryDao.getMessages(sessionId: session.id);
    final partRows = await _chatHistoryDao.getParts(sessionId: session.id);
    final partsByMessage = <String, List<Map<String, dynamic>>>{};
    for (final row in partRows) {
      // Stored (spilled) form, kept verbatim: the audit file references the
      // archived spill directory and never carries base64.
      partsByMessage.putIfAbsent(row.messageId, () => []).add(jsonDecodeMap(row.partJson));
    }

    final file = ArchivedSessionFileDto(
      schemaVersion: _archiveSchemaVersion,
      archivedAt: archivedAt,
      completeness: completeness,
      session: ArchivedSessionSnapshotDto(
        sessionId: session.id,
        backendSessionId: session.backendSessionId,
        pluginId: session.pluginId,
        projectId: session.projectId,
        parentSessionId: session.parentSessionId,
        directory: session.directory,
        worktreePath: session.worktreePath,
        branchName: session.branchName,
        baseBranch: session.baseBranch,
        baseCommit: session.baseCommit,
        lastAgent: lastAgent,
        lastAgentModel: lastAgentModel,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      messages: [
        for (final row in messageRows)
          ArchivedMessageDto(
            seq: row.seq,
            info: Message.fromJson(jsonDecodeMap(row.infoJson)),
            parts: partsByMessage[row.messageId] ?? const [],
          ),
      ],
    );

    // Bytes first: an audit file that references a missing spill file would
    // render degraded, while orphan bytes are harmless.
    await _attachmentSpillStorage.copySession(
      sessionId: session.id,
      destinationDirectoryPath: _archivedAttachmentStorage.sessionDirectoryPath(sessionId: session.id),
    );
    await _archivedSessionStorage.write(sessionId: session.id, contents: jsonEncode(file.toJson()));
  }

  /// The archived transcript for [sessionId], or null when no audit file
  /// exists. Attachments are rehydrated from the archived spill directory.
  Future<ChatHistoryPage?> getArchivedSessionMessages({
    required String sessionId,
    int? limit,
    int? before,
  }) async {
    final contents = await _archivedSessionStorage.read(sessionId: sessionId);
    if (contents == null) return null;

    // Read the version from the raw envelope first. A newer format may change
    // required fields or enum values, so typed decoding would fail and the
    // file would be quarantined as corrupt when it is merely too new.
    final Map<String, dynamic> raw;
    try {
      raw = jsonDecodeMap(contents);
    } on Object catch (error, stackTrace) {
      Log.w("[archive] quarantining an unreadable audit file for session $sessionId", error, stackTrace);
      await _archivedSessionStorage.quarantine(sessionId: sessionId);
      return null;
    }
    // Refuse any version this bridge does not implement, not merely newer
    // ones: an unrecognised older format would otherwise be decoded as v1 and
    // silently misread. There is one version today, so this is exact equality.
    final version = raw["schemaVersion"];
    if (version is! int || version != _archiveSchemaVersion) {
      throw ChatHistoryArchiveVersionException(
        sessionId: sessionId,
        fileVersion: version is int ? version : -1,
        supportedVersion: _archiveSchemaVersion,
      );
    }

    final ArchivedSessionFileDto file;
    try {
      file = ArchivedSessionFileDto.fromJson(raw);
    } on Object catch (error, stackTrace) {
      Log.w("[archive] quarantining an unreadable audit file for session $sessionId", error, stackTrace);
      await _archivedSessionStorage.quarantine(sessionId: sessionId);
      return null;
    }
    if (file.completeness == ArchivedSessionCompleteness.storeOnly) {
      Log.i(
        "[archive] session $sessionId was archived without a backend fetch, "
        "so its audit file may be missing the most recent messages",
      );
    }

    // Archived reads are rare audit views, so the page is sliced in memory
    // rather than earning an index.
    final ordered = file.messages.toList(growable: false)..sort((left, right) => left.seq.compareTo(right.seq));
    final eligible = before == null
        ? ordered
        : [
            for (final entry in ordered)
              if (entry.seq < before) entry,
          ];
    final page = limit == null || eligible.length <= limit ? eligible : eligible.sublist(eligible.length - limit);
    return (
      messages: [
        for (final entry in page)
          MessageWithParts(
            info: entry.info,
            parts: [
              for (final part in entry.parts)
                await _rehydratePart(
                  sessionId: sessionId,
                  partJson: jsonEncode(part),
                  storage: _archivedAttachmentStorage,
                ),
            ],
          ),
      ],
      nextCursor: limit != null && page.isNotEmpty && page.length == limit && eligible.length > limit
          ? page.first.seq
          : null,
    );
  }

  Future<bool> hasArchive({required String sessionId}) => _archivedSessionStorage.exists(sessionId: sessionId);

  Future<Set<String>> getArchivedSessionIds() => _archivedSessionStorage.listArchivedSessionIds();

  /// Drops every trace of [sessionIds] from the store.
  ///
  /// Rows go first so a failure between the two steps leaves orphan bytes
  /// (harmless, removed by the next purge) rather than rows referencing spill
  /// files that no longer exist. Deleting a session family is one transaction
  /// and one vacuum pass, not one of each per descendant.
  Future<void> purgeSessions({
    required List<String> sessionIds,
    bool includeArchive = false,
  }) async {
    if (sessionIds.isEmpty) return;
    await _chatHistoryDao.deleteSessionRows(sessionIds: sessionIds);
    // Every session is attempted even if one directory refuses to go, so a
    // single failure cannot strand the rest of the family's bytes on disk.
    // The first failure is reported once the rest of the work is done.
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final sessionId in sessionIds) {
      try {
        await _attachmentSpillStorage.deleteSession(sessionId: sessionId);
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (includeArchive) {
      for (final sessionId in sessionIds) {
        try {
          await _archivedSessionStorage.delete(sessionId: sessionId);
          await _archivedAttachmentStorage.deleteSession(sessionId: sessionId);
        } on Object catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
    }
    await _chatHistoryDao.reclaimFreedPages();
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStackTrace!);
  }

  /// The stored JSON for [part], with inline attachment bytes moved to spill
  /// files and replaced by a `stored_file` reference.
  ///
  /// The reference is a bridge-internal attachment source that exists only
  /// inside `chat_history.db`; [_rehydratePart] turns it back into the inline
  /// variant before anything can reach the wire.
  Future<String> _encodePart({required String sessionId, required MessagePart part}) async {
    final json = part.toJson();
    if (json["attachment"] case final Map<String, dynamic> attachment) {
      json["attachment"] = await _spillAttachment(sessionId: sessionId, attachment: attachment);
    }
    if (json["state"] case final Map<String, dynamic> state) {
      if (state["attachments"] case final List<dynamic> attachments) {
        state["attachments"] = [
          for (final attachment in attachments)
            if (attachment is Map<String, dynamic>)
              await _spillAttachment(sessionId: sessionId, attachment: attachment)
            else
              attachment,
        ];
      }
    }
    return jsonEncode(json);
  }

  Future<Map<String, dynamic>> _spillAttachment({
    required String sessionId,
    required Map<String, dynamic> attachment,
  }) async {
    if (attachment["source"] != "inline_image") return attachment;
    final base64Data = attachment["base64"];
    if (base64Data is! String || base64Data.isEmpty) {
      return {"source": "metadata", "mime": attachment["mime"], "filename": attachment["filename"]};
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(base64Data);
    } on FormatException {
      // Undecodable inline data cannot be stored or re-served, so keep the
      // slot with the metadata the client can still render.
      return {"source": "metadata", "mime": attachment["mime"], "filename": attachment["filename"]};
    }
    return {
      "source": "stored_file",
      "mime": attachment["mime"],
      "filename": attachment["filename"],
      "sha256": await _attachmentSpillStorage.write(sessionId: sessionId, bytes: bytes),
    };
  }

  Future<MessagePart> _rehydratePart({
    required String sessionId,
    required String partJson,
    AttachmentSpillStorage? storage,
  }) async {
    final json = jsonDecodeMap(partJson);
    if (json["attachment"] case final Map<String, dynamic> attachment) {
      json["attachment"] = await _rehydrateAttachment(
        sessionId: sessionId,
        attachment: attachment,
        storage: storage ?? _attachmentSpillStorage,
      );
    }
    if (json["state"] case final Map<String, dynamic> state) {
      if (state["attachments"] case final List<dynamic> attachments) {
        state["attachments"] = [
          for (final attachment in attachments)
            if (attachment is Map<String, dynamic>)
              await _rehydrateAttachment(
                sessionId: sessionId,
                attachment: attachment,
                storage: storage ?? _attachmentSpillStorage,
              )
            else
              attachment,
        ];
      }
    }
    return MessagePart.fromJson(json);
  }

  Future<Map<String, dynamic>> _rehydrateAttachment({
    required String sessionId,
    required Map<String, dynamic> attachment,
    required AttachmentSpillStorage storage,
  }) async {
    if (attachment["source"] != "stored_file") return attachment;
    final digest = attachment["sha256"];
    final bytes = digest is String ? await storage.read(sessionId: sessionId, digest: digest) : null;
    // A missing spill file degrades the slot instead of failing the read.
    if (bytes == null) {
      return {"source": "metadata", "mime": attachment["mime"], "filename": attachment["filename"]};
    }
    return {
      "source": "inline_image",
      "mime": attachment["mime"],
      "filename": attachment["filename"],
      "base64": base64Encode(bytes),
    };
  }
}

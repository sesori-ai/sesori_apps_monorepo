import "dart:convert";
import "dart:typed_data";

import "package:sesori_shared/sesori_shared.dart";

import "../../api/attachment_spill_storage.dart";
import "../../api/database/history/chat_history_dao.dart";
import "../../api/database/history/chat_history_database.dart";

/// One page of stored history, oldest-first, plus the cursor for the next
/// older page (null when the caller has reached the start of the transcript).
typedef ChatHistoryPage = ({List<MessageWithParts> messages, int? nextCursor});

/// How fresh a session's stored transcript is.
///
/// [syncedAt] is null until a backfill completes, so a row created by live
/// capture never claims to be a complete transcript.
typedef ChatHistorySyncState = ({int watermark, int backendActivityAt, int? syncedAt});

/// Owns the stored representation of chat history: database rows, their JSON
/// payloads, and the attachment spill files those payloads reference.
class ChatHistoryRepository {
  ChatHistoryRepository({
    required ChatHistoryDao chatHistoryDao,
    required AttachmentSpillStorage attachmentSpillStorage,
  }) : _chatHistoryDao = chatHistoryDao,
       _attachmentSpillStorage = attachmentSpillStorage;

  final ChatHistoryDao _chatHistoryDao;
  final AttachmentSpillStorage _attachmentSpillStorage;

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

  /// Drops every trace of [sessionIds] from the store.
  ///
  /// Rows go first so a failure between the two steps leaves orphan bytes
  /// (harmless, removed by the next purge) rather than rows referencing spill
  /// files that no longer exist. Deleting a session family is one transaction
  /// and one vacuum pass, not one of each per descendant.
  Future<void> purgeSessions({required List<String> sessionIds}) async {
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

  Future<MessagePart> _rehydratePart({required String sessionId, required String partJson}) async {
    final json = jsonDecodeMap(partJson);
    if (json["attachment"] case final Map<String, dynamic> attachment) {
      json["attachment"] = await _rehydrateAttachment(sessionId: sessionId, attachment: attachment);
    }
    if (json["state"] case final Map<String, dynamic> state) {
      if (state["attachments"] case final List<dynamic> attachments) {
        state["attachments"] = [
          for (final attachment in attachments)
            if (attachment is Map<String, dynamic>)
              await _rehydrateAttachment(sessionId: sessionId, attachment: attachment)
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
  }) async {
    if (attachment["source"] != "stored_file") return attachment;
    final digest = attachment["sha256"];
    final bytes = digest is String
        ? await _attachmentSpillStorage.read(sessionId: sessionId, digest: digest)
        : null;
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

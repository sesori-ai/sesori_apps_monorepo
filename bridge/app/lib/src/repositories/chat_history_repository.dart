import "dart:convert";
import "dart:typed_data";

import "package:crypto/crypto.dart" show sha256;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../api/archived_session_storage.dart";
import "../api/attachment_spill_storage.dart";
import "../api/database/history/chat_history_dao.dart";
import "../api/database/history/chat_history_database.dart";
import "../api/models/archived_session_file_dto.dart";
import "models/stored_session.dart";

/// Raised when an audit file was written by a newer bridge than this one.
class ChatHistoryArchiveVersionException({
  required final String sessionId,
  required final int fileVersion,
  required final int supportedVersion,
}) implements Exception {
  @override
  String toString() =>
      "archived history for session $sessionId is schema "
      "${fileVersion < 0 ? "unreadable" : "v$fileVersion"}, "
      "which this bridge (v$supportedVersion) cannot read";
}

/// One page of stored history, oldest-first, plus the cursor for the next
/// older page (null when the caller has reached the start of the transcript).
typedef ChatHistoryPage = ({List<MessageWithParts> messages, int? nextCursor});

/// Identity of one stored part inside its session.
typedef StoredPartRef = ({String messageId, String partId});
typedef _SemanticMessageFingerprints = ({String content, String context});

/// How fresh a session's stored transcript is.
///
/// [syncedAt] is null until a backfill completes, so a row created by live
/// capture never claims to be a complete transcript.
typedef ChatHistorySyncState = ({int watermark, int backendActivityAt, int? syncedAt});

typedef StoredAttachmentThumbnail = ({
  Uint8List bytes,
  AttachmentThumbnailFormat format,
});

sealed class const MessageAttachmentProjection();

final class const InlineMessageAttachmentProjection() extends MessageAttachmentProjection;

final class const StoredReferenceMessageAttachmentProjection({required final String bridgeId})
    extends MessageAttachmentProjection;

/// Owns the stored representation of chat history: database rows, their JSON
/// payloads, and the attachment spill files those payloads reference.
class ChatHistoryRepository({
  required final ChatHistoryDao _chatHistoryDao,
  required final AttachmentSpillStorage _attachmentSpillStorage,
  required final ArchivedSessionStorage _archivedSessionStorage,
}) {
  static const _archiveSchemaVersion = 1;
  static const _semanticMatchBridgeId = "history-semantic-match";

  Future<Uint8List?> readStoredAttachment({
    required AttachmentStorageScope storageScope,
    required String attachmentId,
  }) async {
    if (!AttachmentSpillStorage.isContentAddress(digest: attachmentId)) return null;
    return await _attachmentSpillStorage.read(scope: storageScope, digest: attachmentId);
  }

  Future<StoredAttachmentThumbnail?> readStoredAttachmentThumbnail({
    required AttachmentStorageScope storageScope,
    required String attachmentId,
  }) async {
    if (!AttachmentSpillStorage.isContentAddress(digest: attachmentId)) return null;
    final thumbnail = await _attachmentSpillStorage.readThumbnail(
      scope: storageScope,
      digest: attachmentId,
    );
    return thumbnail == null ? null : (bytes: thumbnail.bytes, format: thumbnail.format);
  }

  Future<bool> writeStoredAttachmentThumbnail({
    required AttachmentStorageScope storageScope,
    required String attachmentId,
    required AttachmentThumbnailFormat format,
    required Uint8List bytes,
  }) {
    if (!AttachmentSpillStorage.isContentAddress(digest: attachmentId)) return Future.value(false);
    return _attachmentSpillStorage.writeThumbnail(
      scope: storageScope,
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
    required AttachmentStorageScope storageScope,
    int? limit,
    int? before,
    required MessageAttachmentProjection attachmentProjection,
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
    final partJsonByMessage = <String, List<String>>{};
    for (final row in partRows) {
      partJsonByMessage.putIfAbsent(row.messageId, () => []).add(row.partJson);
    }
    final messages = [
      for (final row in messageRows)
        MessageWithParts(
          info: Message.fromJson(jsonDecodeMap(row.infoJson)),
          parts: await _rehydrateParts(
            storageScope: storageScope,
            partJsons: partJsonByMessage[row.messageId] ?? const [],
            attachmentProjection: attachmentProjection,
          ),
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
    required AttachmentStorageScope storageScope,
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
    final boundedPart = _hasInlineImage(part: part)
        ? await _boundPartForTranscriptRetention(sessionId: sessionId, part: part, orderIndex: orderIndex)
        : part;
    await _chatHistoryDao.upsertPart(
      row: HistoryPartsTableData(
        sessionId: sessionId,
        messageId: boundedPart.messageID,
        partId: boundedPart.id,
        orderIndex: orderIndex,
        partJson: await _encodePart(storageScope: storageScope, part: boundedPart),
        updatedAt: updatedAt,
      ),
    );
  }

  Future<MessagePart> _boundPartForTranscriptRetention({
    required String sessionId,
    required MessagePart part,
    required int orderIndex,
  }) async {
    final rows = await _chatHistoryDao.getParts(sessionId: sessionId, messageIds: [part.messageID]);
    var remainingBytes = maxTranscriptImageCollectionBytes;
    for (final row in rows) {
      if (row.orderIndex == orderIndex) continue;
      remainingBytes -= _storedImageBytes(partJson: row.partJson);
    }

    MessageAttachment bound({required MessageAttachment attachment}) {
      if (attachment case MessageAttachmentInlineImage(:final mime, :final base64, :final filename)) {
        final decodedBytes = decodedBase64Length(base64Data: base64);
        if (decodedBytes > remainingBytes) {
          return MessageAttachment.metadata(mime: mime, filename: filename);
        }
        remainingBytes -= decodedBytes;
      }
      return attachment;
    }

    return switch (part) {
      MessagePartFile(:final attachment) => part.copyWith(attachment: bound(attachment: attachment)),
      MessagePartTool(:final state) => part.copyWith(
        state: state.copyWith(
          attachments: state.attachments.map((attachment) => bound(attachment: attachment)).toList(),
        ),
      ),
      _ => part,
    };
  }

  bool _hasInlineImage({required MessagePart part}) => switch (part) {
    MessagePartFile(:final attachment) => attachment is MessageAttachmentInlineImage,
    MessagePartTool(:final state) => state.attachments.any(
      (attachment) => attachment is MessageAttachmentInlineImage,
    ),
    _ => false,
  };

  int _storedImageBytes({required String partJson}) {
    final json = jsonDecodeMap(partJson);
    var total = 0;

    void add(Map<String, dynamic> attachment) {
      if (attachment["source"] != "stored_file") return;
      final byteLength = attachment["byteLength"];
      if (byteLength is int && byteLength > 0) total += byteLength;
    }

    final Object? attachmentValue = json["attachment"];
    if (attachmentValue case final Map<dynamic, dynamic> attachment) {
      add(Map<String, dynamic>.from(attachment));
    }
    final Object? stateValue = json["state"];
    if (stateValue case final Map<dynamic, dynamic> state) {
      final typedState = Map<String, dynamic>.from(state);
      final Object? attachmentsValue = typedState["attachments"];
      if (attachmentsValue case final List<dynamic> attachments) {
        for (final attachment in attachments) {
          final Object? attachmentValue = attachment;
          if (attachmentValue is Map<dynamic, dynamic>) add(Map<String, dynamic>.from(attachmentValue));
        }
      }
    }
    return total;
  }

  /// One stored part projected for delivery, or null when the row is gone.
  ///
  /// The legacy inline budget is consumed by the part's stored siblings in
  /// collection order first, so a message whose images arrive as separate part
  /// updates degrades exactly where one combined page would.
  Future<MessagePart?> projectStoredPart({
    required String sessionId,
    required AttachmentStorageScope storageScope,
    required String messageId,
    required String partId,
    required MessageAttachmentProjection attachmentProjection,
  }) async {
    final rows = await _chatHistoryDao.getParts(sessionId: sessionId, messageIds: [messageId]);
    var remainingInlineBytes = maxInlineMessageAttachmentBytes;
    for (final row in rows) {
      final projected = await _rehydratePart(
        storageScope: storageScope,
        partJson: row.partJson,
        attachmentProjection: attachmentProjection,
        remainingInlineBytes: remainingInlineBytes,
      );
      if (row.partId == partId) return projected.part;
      remainingInlineBytes = projected.remainingInlineBytes;
    }
    return null;
  }

  /// Rewrites every stored tool part still in a non-terminal state to a
  /// terminal error, and returns the identity of each rewritten row.
  ///
  /// A tool part left `pending`/`running` after its turn ended can never
  /// receive a result — the backend reports tool completion only within the
  /// turn that ran it — so keeping the stored snapshot open would render an
  /// eternal spinner on every later read.
  Future<List<StoredPartRef>> finalizeOpenToolParts({
    required String sessionId,
    required int updatedAt,
  }) async {
    final rows = await _chatHistoryDao.getParts(sessionId: sessionId);
    final finalized = <StoredPartRef>[];
    for (final row in rows) {
      // Cheap prefilter so an idle sweep does not decode a whole transcript;
      // the decoded check below remains the only authority.
      if (!row.partJson.contains('"status":"pending"') && !row.partJson.contains('"status":"running"')) {
        continue;
      }
      final Map<String, dynamic> json;
      try {
        json = jsonDecodeMap(row.partJson);
      } on Object catch (error, stackTrace) {
        Log.w(
          "Skipping an undecodable stored part ${row.partId} of session $sessionId during tool finalization",
          error,
          stackTrace,
        );
        continue;
      }
      if (json["type"] != "tool") continue;
      final Object? rawState = json["state"];
      if (rawState is! Map<String, dynamic>) continue;
      final status = rawState["status"];
      if (status != "pending" && status != "running") continue;

      rawState["status"] = "error";
      rawState["error"] = "The turn ended before this tool reported a result.";
      await _chatHistoryDao.upsertPart(
        row: row.copyWith(partJson: jsonEncode(json), updatedAt: updatedAt),
      );
      finalized.add((messageId: row.messageId, partId: row.partId));
    }
    return finalized;
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
  /// Rows the transcript does not contain are retained only when they were
  /// written after [lastImportedAt], the moment the previous import finished.
  /// Those are the rows that import could not have covered: a live capture
  /// since, or one the backend never reports at all. An older row was in an
  /// earlier transcript and is not in this one, so the backend removed it —
  /// an edited message rolls its session back, and a bridge that was not
  /// watching that backend sees the removal only as this gap. Keeping it would
  /// restore messages the user deleted elsewhere. A session with no completed
  /// import has no such line to draw, so stored rows are otherwise kept.
  ///
  /// Backend replay identities can differ from the live identities Sesori
  /// assigned to the same visible messages. Normalized semantic matching in the
  /// same nearest-distinct visible-message context drops retained duplicates up
  /// to the imported multiplicity while preserving truly live-only rows and
  /// additional identical messages. The imported row remains authoritative for
  /// replay metadata.
  ///
  /// Retained rows rejoin the imported transcript at their recorded message
  /// time while their relative order stays stable. Thus an older backend-only
  /// row cannot jump to the newest edge on re-import, while a genuinely newer
  /// live row stays there.
  Future<void> replaceSessionMessages({
    required String sessionId,
    required AttachmentStorageScope storageScope,
    required List<MessageWithParts> messages,
    required int? lastImportedAt,
    required int watermark,
    required int backendActivityAt,
    required int syncedAt,
  }) async {
    final importedIds = {for (final message in messages) message.info.id};
    final storedRows = await _chatHistoryDao.getMessages(sessionId: sessionId);
    final storedPartRows = await _chatHistoryDao.getParts(sessionId: sessionId);
    final storedPartJsonByMessage = <String, List<String>>{};
    for (final row in storedPartRows) {
      storedPartJsonByMessage.putIfAbsent(row.messageId, () => []).add(row.partJson);
    }

    final importedMessageRows = <HistoryMessagesTableData>[];
    final importedPartJsonByMessage = <String, List<String>>{};
    final partRows = <HistoryPartsTableData>[];
    var seq = 0;
    for (final message in messages) {
      seq++;
      final infoJson = jsonEncode(message.info.toJson());
      importedMessageRows.add(
        HistoryMessagesTableData(
          sessionId: sessionId,
          messageId: message.info.id,
          seq: seq,
          infoJson: infoJson,
          updatedAt: syncedAt,
        ),
      );
      for (var index = 0; index < message.parts.length; index++) {
        final part = message.parts[index];
        final partJson = await _encodePart(storageScope: storageScope, part: part);
        importedPartJsonByMessage.putIfAbsent(message.info.id, () => []).add(partJson);
        partRows.add(
          HistoryPartsTableData(
            sessionId: sessionId,
            messageId: message.info.id,
            partId: part.id,
            orderIndex: index,
            partJson: partJson,
            updatedAt: syncedAt,
          ),
        );
      }
    }

    final importedSemanticFingerprints = <_SemanticMessageFingerprints?>[];
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      importedSemanticFingerprints.add(
        await _semanticMessageFingerprints(
          sessionId: sessionId,
          messageId: message.info.id,
          storageScope: storageScope,
          infoJson: importedMessageRows[index].infoJson,
          partJsons: importedPartJsonByMessage[message.info.id] ?? const [],
        ),
      );
    }

    final storedSemanticFingerprints = <_SemanticMessageFingerprints?>[];
    for (final row in storedRows) {
      storedSemanticFingerprints.add(
        await _semanticMessageFingerprints(
          sessionId: sessionId,
          messageId: row.messageId,
          storageScope: storageScope,
          infoJson: row.infoJson,
          partJsons: storedPartJsonByMessage[row.messageId] ?? const [],
        ),
      );
    }

    final importedSemanticContexts = _semanticContextFingerprints(fingerprints: importedSemanticFingerprints);
    final storedSemanticContexts = _semanticContextFingerprints(fingerprints: storedSemanticFingerprints);
    final importedSemanticCounts = <String, int>{};
    for (final fingerprint in importedSemanticContexts) {
      if (fingerprint != null) importedSemanticCounts[fingerprint] = (importedSemanticCounts[fingerprint] ?? 0) + 1;
    }

    final storedSemanticOccurrences = <String, int>{};
    final semanticallyImportedStoredIds = <String>{};
    for (var index = 0; index < storedRows.length; index++) {
      final row = storedRows[index];
      if (importedIds.contains(row.messageId) || (lastImportedAt != null && row.updatedAt <= lastImportedAt)) continue;
      final fingerprint = storedSemanticContexts[index];
      if (fingerprint == null) continue;
      final occurrence = (storedSemanticOccurrences[fingerprint] ?? 0) + 1;
      storedSemanticOccurrences[fingerprint] = occurrence;
      if (occurrence <= (importedSemanticCounts[fingerprint] ?? 0)) {
        semanticallyImportedStoredIds.add(row.messageId);
      }
    }

    final retained = [
      for (final row in storedRows)
        if (!importedIds.contains(row.messageId) &&
            !semanticallyImportedStoredIds.contains(row.messageId) &&
            (lastImportedAt == null || row.updatedAt > lastImportedAt))
          row,
    ];
    final retainedCreatedAt = [
      for (final row in retained) Message.fromJson(jsonDecodeMap(row.infoJson)).time?.created,
    ];
    int? nextRetainedCreatedAt;
    for (var index = retainedCreatedAt.length - 1; index >= 0; index--) {
      nextRetainedCreatedAt = retainedCreatedAt[index] ?? nextRetainedCreatedAt;
      retainedCreatedAt[index] = nextRetainedCreatedAt;
    }
    int? previousRetainedCreatedAt;
    for (var index = 0; index < retainedCreatedAt.length; index++) {
      final createdAt = retainedCreatedAt[index] ?? previousRetainedCreatedAt;
      if (createdAt == null) continue;
      final orderedCreatedAt = previousRetainedCreatedAt == null || createdAt >= previousRetainedCreatedAt
          ? createdAt
          : previousRetainedCreatedAt;
      retainedCreatedAt[index] = orderedCreatedAt;
      previousRetainedCreatedAt = orderedCreatedAt;
    }

    final messageRows = <HistoryMessagesTableData>[];
    var importedIndex = 0;
    var retainedIndex = 0;
    while (importedIndex < importedMessageRows.length || retainedIndex < retained.length) {
      final useRetained =
          importedIndex == importedMessageRows.length ||
          (retainedIndex < retained.length &&
              retainedCreatedAt[retainedIndex] != null &&
              messages[importedIndex].info.time?.created != null &&
              retainedCreatedAt[retainedIndex]! < messages[importedIndex].info.time!.created);
      final row = useRetained ? retained[retainedIndex++] : importedMessageRows[importedIndex++];
      final orderedSeq = messageRows.length + 1;
      messageRows.add(row.seq == orderedSeq ? row : row.copyWith(seq: orderedSeq));
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

  Future<void> clearSyncedAtForSessions({required List<String> sessionIds}) {
    return _chatHistoryDao.clearSyncedAtForSessions(sessionIds: sessionIds);
  }

  Future<Set<String>> getStoredSessionIds() => _chatHistoryDao.getStoredSessionIds();

  /// Writes the session's audit file. Its attachment references continue to
  /// address the shared backend-session scope; archiving does not copy bytes.
  Future<void> exportSession({
    required StoredSession session,
    required String? title,
    required int createdAt,
    required int updatedAt,
    required int archivedAt,
    required ArchivedSessionCompleteness completeness,
  }) async {
    final messageRows = await _chatHistoryDao.getMessages(sessionId: session.id);
    final partRows = await _chatHistoryDao.getParts(sessionId: session.id);
    final partsByMessage = <String, List<Map<String, dynamic>>>{};
    for (final row in partRows) {
      // Stored (spilled) form, kept verbatim: the audit file references the
      // shared spill scope and never carries base64.
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

    await _archivedSessionStorage.write(sessionId: session.id, contents: jsonEncode(file.toJson()));
  }

  /// The archived transcript for [sessionId], or null when no audit file
  /// exists. Attachments are rehydrated from the shared backend-session scope.
  Future<ChatHistoryPage?> getArchivedSessionMessages({
    required String sessionId,
    required AttachmentStorageScope storageScope,
    int? limit,
    int? before,
    required MessageAttachmentProjection attachmentProjection,
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
            parts: await _rehydrateParts(
              storageScope: storageScope,
              partJsons: [for (final part in entry.parts) jsonEncode(part)],
              attachmentProjection: attachmentProjection,
            ),
          ),
      ],
      nextCursor: limit != null && page.isNotEmpty && page.length == limit && eligible.length > limit
          ? page.first.seq
          : null,
    );
  }

  Future<bool> hasArchive({required String sessionId}) => _archivedSessionStorage.exists(sessionId: sessionId);

  Future<Set<String>> getArchivedSessionIds() => _archivedSessionStorage.listArchivedSessionIds();

  /// Drops data-directory-local history for [sessionIds]. Shared attachment
  /// bytes have manual lifetime because another bridge database may reference
  /// the same backend-session scope.
  Future<void> purgeSessions({
    required List<String> sessionIds,
    bool includeArchive = false,
  }) async {
    if (sessionIds.isEmpty) return;
    await _chatHistoryDao.deleteSessionRows(sessionIds: sessionIds);
    Object? firstError;
    StackTrace? firstStackTrace;
    if (includeArchive) {
      for (final sessionId in sessionIds) {
        try {
          await _archivedSessionStorage.delete(sessionId: sessionId);
        } on Object catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
    }
    await _chatHistoryDao.reclaimFreedPages();
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStackTrace!);
  }

  Future<_SemanticMessageFingerprints?> _semanticMessageFingerprints({
    required String sessionId,
    required String messageId,
    required AttachmentStorageScope storageScope,
    required String infoJson,
    required List<String> partJsons,
  }) async {
    try {
      final info = _withoutFields(
        source: Message.fromJson(jsonDecodeMap(infoJson)).toJson(),
        fields: const {"id", "sessionID", "promptId", "time", "agent", "modelID", "providerID"},
      );
      final parts = await _rehydrateParts(
        storageScope: storageScope,
        partJsons: partJsons,
        attachmentProjection: const StoredReferenceMessageAttachmentProjection(bridgeId: _semanticMatchBridgeId),
      );
      final canonicalParts = [
        for (final part in parts)
          _withoutFields(
            source: part.toJson(),
            fields: const {"id", "sessionID", "messageID"},
          ),
      ];
      return (
        content: _jsonFingerprint(value: {"info": info, "parts": canonicalParts}),
        context: _jsonFingerprint(
          value: {
            "info": info,
            "parts": [
              for (var index = 0; index < parts.length; index++)
                if (parts[index] is! MessagePartReasoning) canonicalParts[index],
            ],
          },
        ),
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "[history] could not compare message $messageId in session $sessionId during replay reconciliation",
        error,
        stackTrace,
      );
      return null;
    }
  }

  String _jsonFingerprint({required Object value}) => sha256.convert(utf8.encode(jsonEncode(value))).toString();

  List<String?> _semanticContextFingerprints({required List<_SemanticMessageFingerprints?> fingerprints}) {
    final previousDistinct = List<String?>.filled(fingerprints.length, null);
    String? currentRun;
    String? beforeRun;
    for (var index = 0; index < fingerprints.length; index++) {
      final fingerprint = fingerprints[index]?.context;
      if (fingerprint == null) continue;
      if (fingerprint != currentRun) {
        beforeRun = currentRun;
        currentRun = fingerprint;
      }
      previousDistinct[index] = beforeRun;
    }

    final nextDistinct = List<String?>.filled(fingerprints.length, null);
    currentRun = null;
    String? afterRun;
    for (var index = fingerprints.length - 1; index >= 0; index--) {
      final fingerprint = fingerprints[index]?.context;
      if (fingerprint == null) continue;
      if (fingerprint != currentRun) {
        afterRun = currentRun;
        currentRun = fingerprint;
      }
      nextDistinct[index] = afterRun;
    }

    return [
      for (var index = 0; index < fingerprints.length; index++)
        if (fingerprints[index] case final _SemanticMessageFingerprints fingerprint)
          jsonEncode([previousDistinct[index], fingerprint.content, nextDistinct[index]])
        else
          null,
    ];
  }

  Map<String, dynamic> _withoutFields({
    required Map<String, dynamic> source,
    required Set<String> fields,
  }) {
    final result = Map<String, dynamic>.of(source);
    fields.forEach(result.remove);
    return result;
  }

  /// The stored JSON for [part], with inline attachment bytes moved to spill
  /// files and replaced by a `stored_file` reference.
  ///
  /// The reference is a bridge-internal attachment source that exists only
  /// inside `chat_history.db`; [_rehydratePart] projects it into the delivery
  /// shape requested by the client before anything reaches the wire.
  Future<String> _encodePart({
    required AttachmentStorageScope storageScope,
    required MessagePart part,
  }) async {
    final json = part.toJson();
    final Object? rawAttachment = json["attachment"];
    if (rawAttachment case final Map<String, dynamic> attachment) {
      json["attachment"] = await _spillAttachment(
        storageScope: storageScope,
        attachment: attachment,
      );
    }
    final Object? rawState = json["state"];
    if (rawState case final Map<String, dynamic> state) {
      final Object? rawAttachments = state["attachments"];
      if (rawAttachments case final List<dynamic> attachments) {
        state["attachments"] = [
          for (final attachment in attachments)
            if (attachment is Map<String, dynamic>)
              await _spillAttachment(
                storageScope: storageScope,
                attachment: attachment,
              )
            else
              attachment,
        ];
      }
    }
    return jsonEncode(json);
  }

  Future<Map<String, dynamic>> _spillAttachment({
    required AttachmentStorageScope storageScope,
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
      "sha256": await _attachmentSpillStorage.write(scope: storageScope, bytes: bytes),
      "byteLength": bytes.length,
    };
  }

  Future<List<MessagePart>> _rehydrateParts({
    required AttachmentStorageScope storageScope,
    required List<String> partJsons,
    required MessageAttachmentProjection attachmentProjection,
  }) async {
    var remainingInlineBytes = maxInlineMessageAttachmentBytes;
    final parts = <MessagePart>[];
    for (final partJson in partJsons) {
      final projected = await _rehydratePart(
        storageScope: storageScope,
        partJson: partJson,
        attachmentProjection: attachmentProjection,
        remainingInlineBytes: remainingInlineBytes,
      );
      parts.add(projected.part);
      remainingInlineBytes = projected.remainingInlineBytes;
    }
    return parts;
  }

  Future<({MessagePart part, int remainingInlineBytes})> _rehydratePart({
    required AttachmentStorageScope storageScope,
    required String partJson,
    required MessageAttachmentProjection attachmentProjection,
    required int remainingInlineBytes,
  }) async {
    var remaining = remainingInlineBytes;
    final json = jsonDecodeMap(partJson);
    final Object? rawAttachment = json["attachment"];
    if (rawAttachment case final Map<String, dynamic> attachment) {
      final projected = await _rehydrateAttachment(
        storageScope: storageScope,
        attachment: attachment,
        attachmentProjection: attachmentProjection,
        remainingInlineBytes: remaining,
      );
      json["attachment"] = projected.attachment;
      remaining = projected.remainingInlineBytes;
    }
    final Object? rawState = json["state"];
    if (rawState case final Map<String, dynamic> state) {
      final Object? rawAttachments = state["attachments"];
      if (rawAttachments case final List<dynamic> attachments) {
        final projectedAttachments = <dynamic>[];
        for (final attachment in attachments) {
          if (attachment is! Map<String, dynamic>) {
            projectedAttachments.add(attachment);
            continue;
          }
          final projected = await _rehydrateAttachment(
            storageScope: storageScope,
            attachment: attachment,
            attachmentProjection: attachmentProjection,
            remainingInlineBytes: remaining,
          );
          projectedAttachments.add(projected.attachment);
          remaining = projected.remainingInlineBytes;
        }
        state["attachments"] = projectedAttachments;
      }
    }
    return (part: MessagePart.fromJson(json), remainingInlineBytes: remaining);
  }

  Future<({Map<String, dynamic> attachment, int remainingInlineBytes})> _rehydrateAttachment({
    required AttachmentStorageScope storageScope,
    required Map<String, dynamic> attachment,
    required MessageAttachmentProjection attachmentProjection,
    required int remainingInlineBytes,
  }) async {
    if (attachment["source"] == "inline_image" && attachmentProjection is InlineMessageAttachmentProjection) {
      final base64Data = attachment["base64"];
      if (base64Data is String) {
        final byteLength = decodedBase64Length(base64Data: base64Data);
        if (byteLength > remainingInlineBytes) {
          return (
            attachment: _metadataAttachment(attachment: attachment),
            remainingInlineBytes: remainingInlineBytes,
          );
        }
        return (
          attachment: attachment,
          remainingInlineBytes: remainingInlineBytes - byteLength,
        );
      }
      return (attachment: attachment, remainingInlineBytes: remainingInlineBytes);
    }
    if (attachment["source"] != "stored_file") {
      return (attachment: attachment, remainingInlineBytes: remainingInlineBytes);
    }
    final digest = attachment["sha256"];
    if (digest is! String || !AttachmentSpillStorage.isContentAddress(digest: digest)) {
      return (
        attachment: _metadataAttachment(attachment: attachment),
        remainingInlineBytes: remainingInlineBytes,
      );
    }
    final actualByteLength = await _attachmentSpillStorage.byteLength(
      scope: storageScope,
      digest: digest,
    );
    if (actualByteLength == null) {
      return (
        attachment: _metadataAttachment(attachment: attachment),
        remainingInlineBytes: remainingInlineBytes,
      );
    }
    if (attachmentProjection case StoredReferenceMessageAttachmentProjection(:final bridgeId)) {
      final storedByteLength = attachment["byteLength"];
      return (
        attachment: {
          "source": "stored_image",
          "attachmentId": digest,
          "bridgeId": bridgeId,
          "mime": attachment["mime"],
          "filename": attachment["filename"],
          "byteLength": storedByteLength is int && storedByteLength >= 0 ? storedByteLength : actualByteLength,
        },
        remainingInlineBytes: remainingInlineBytes,
      );
    }
    if (actualByteLength > remainingInlineBytes) {
      return (
        attachment: _metadataAttachment(attachment: attachment),
        remainingInlineBytes: remainingInlineBytes,
      );
    }
    final bytes = await _attachmentSpillStorage.read(scope: storageScope, digest: digest);
    if (bytes == null || bytes.length > remainingInlineBytes) {
      return (
        attachment: _metadataAttachment(attachment: attachment),
        remainingInlineBytes: remainingInlineBytes,
      );
    }
    return (
      attachment: {
        "source": "inline_image",
        "mime": attachment["mime"],
        "filename": attachment["filename"],
        "base64": base64Encode(bytes),
      },
      remainingInlineBytes: remainingInlineBytes - bytes.length,
    );
  }

  Map<String, dynamic> _metadataAttachment({required Map<String, dynamic> attachment}) => {
    "source": "metadata",
    "mime": attachment["mime"],
    "filename": attachment["filename"],
  };
}

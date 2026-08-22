import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:sesori_bridge/src/api/attachment_spill_storage.dart";
import "package:sesori_bridge/src/api/database/history/chat_history_database.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/repositories/attachment_thumbnail_builder.dart";
import "package:sesori_bridge/src/repositories/chat_history_repository.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/chat_history_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  group("awaited capture predicate", () {
    test("selects only parts carrying bridge-owned image bytes", () {
      final history = createTestChatHistory();

      expect(
        history.service.requiresAwaitedAttachmentCapture(
          part: _part(
            id: "p1",
            attachment: MessageAttachment.inlineImage(
              mime: "image/png",
              base64: base64Encode(Uint8List.fromList([1, 2, 3])),
              filename: "shot.png",
            ),
          ),
        ),
        isTrue,
      );
      expect(
        history.service.requiresAwaitedAttachmentCapture(
          part: _part(
            id: "p2",
            state: ToolState(
              status: ToolStatus.completed,
              title: null,
              output: null,
              error: null,
              attachments: [
                const MessageAttachment.metadata(mime: "text/plain", filename: "notes.txt"),
                MessageAttachment.inlineImage(
                  mime: "image/png",
                  base64: base64Encode(Uint8List.fromList([4, 5])),
                  filename: "tool.png",
                ),
              ],
            ),
          ),
        ),
        isTrue,
      );
      expect(history.service.requiresAwaitedAttachmentCapture(part: _part(id: "p3")), isFalse);
      expect(
        history.service.requiresAwaitedAttachmentCapture(
          part: _part(
            id: "p4",
            attachment: const MessageAttachment.remoteUrl(
              mime: "image/jpeg",
              url: "https://example.com/a.jpg",
              filename: null,
            ),
          ),
        ),
        isFalse,
      );
    });
  });

  group("capturePartForDelivery", () {
    test("persists once and returns both delivery shapes", () async {
      final history = createTestChatHistory();
      final bytes = Uint8List.fromList(List<int>.generate(64, (index) => index));
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );

      final captured = await history.service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "p1",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(bytes),
            filename: "shot.png",
          ),
        ),
      );

      final rows = await history.database.chatHistoryDao.getParts(sessionId: "ses_a");
      expect(rows, hasLength(1), reason: "one event stores one row");
      expect(rows.single.partJson, isNot(contains(base64Encode(bytes))));
      expect(rows.single.partJson, contains("stored_file"));

      final shapes = captured as CapturedPartShapes;
      expect(
        shapes.inlinePart.attachment,
        isA<MessageAttachmentInlineImage>().having((image) => image.base64, "base64", base64Encode(bytes)),
      );
      expect(
        shapes.storedReferencePart.attachment,
        isA<MessageAttachmentStoredImage>()
            .having((image) => image.bridgeId, "bridgeId", "br_test1234")
            .having((image) => image.byteLength, "byteLength", bytes.length),
      );
      expect(
        jsonEncode(shapes.storedReferencePart.toJson()),
        isNot(contains(base64Encode(bytes))),
        reason: "a reference shape never carries the original bytes",
      );
    });

    test("retains a larger original while keeping the legacy live shape bounded", () async {
      final history = createTestChatHistory();
      final bytes = Uint8List(maxInlineMessageAttachmentBytes + 1);

      final captured = await history.service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "large",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(bytes),
            filename: "large.png",
          ),
        ),
      ) as CapturedPartShapes;

      expect(captured.inlinePart.attachment, isA<MessageAttachmentMetadata>());
      expect(
        captured.storedReferencePart.attachment,
        isA<MessageAttachmentStoredImage>().having((image) => image.byteLength, "byteLength", bytes.length),
      );
    });

    test("advances the same freshness marks as ordinary capture", () async {
      final history = createTestChatHistory();

      await history.service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "p1",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List.fromList([1])),
            filename: null,
          ),
        ),
      );

      final state = await history.repository.getSyncState(sessionId: "ses_a");
      expect(state, isNotNull);
      expect(state!.syncedAt, isNull, reason: "only a completed backfill may claim a complete transcript");
      expect(state.watermark, greaterThan(0));
      expect(state.backendActivityAt, greaterThan(0));
    });

    test("does not persist when the source becomes stale while queued", () async {
      final history = createTestChatHistory();
      final blocker = Completer<void>();
      final blockingRepository = _BlockingWriteRepository(
        blocker: blocker,
        chatHistoryDao: history.database.chatHistoryDao,
        attachmentSpillStorage: history.spillStorage,
        archivedSessionStorage: history.archivedStorage,
      );
      final service = ChatHistoryService(
        chatHistoryRepository: blockingRepository,
        sessionRepository: _BackfillingSessionRepository(),
        attachmentThumbnailBuilder: const AttachmentThumbnailBuilder(),
        bridgeIdProvider: const _BridgeIdProvider("br_test1234"),
      );
      var current = true;
      final precedingCapture = service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "blocker"),
      );
      await blockingRepository.blocked;

      final capture = service.capturePartForDelivery(
        sessionId: "ses_a",
        part: _part(
          id: "stale",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List.fromList([1, 2, 3])),
            filename: "stale.png",
          ),
        ),
        shouldCapture: () => current,
      );
      current = false;
      blocker.complete();

      await precedingCapture;
      expect(await capture, isA<CapturedPartUnavailable>());
      final rows = await history.database.chatHistoryDao.getParts(sessionId: "ses_a");
      expect(rows.map((row) => row.partId), equals(["blocker"]));
    });

    test("does not remove a part when the source becomes stale while queued", () async {
      final history = createTestChatHistory();
      await history.service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "kept"),
      );
      final blocker = Completer<void>();
      final blockingRepository = _BlockingWriteRepository(
        blocker: blocker,
        chatHistoryDao: history.database.chatHistoryDao,
        attachmentSpillStorage: history.spillStorage,
        archivedSessionStorage: history.archivedStorage,
      );
      final service = ChatHistoryService(
        chatHistoryRepository: blockingRepository,
        sessionRepository: _BackfillingSessionRepository(),
        attachmentThumbnailBuilder: const AttachmentThumbnailBuilder(),
        bridgeIdProvider: const _BridgeIdProvider("br_test1234"),
      );
      var current = true;
      final precedingCapture = service.capturePart(
        sessionId: "ses_a",
        part: _part(id: "blocker"),
      );
      await blockingRepository.blocked;

      final removal = service.capturePartRemoved(
        sessionId: "ses_a",
        messageId: "m1",
        partId: "kept",
        shouldCapture: () => current,
      );
      current = false;
      blocker.complete();

      await precedingCapture;
      await removal;
      final rows = await history.database.chatHistoryDao.getParts(sessionId: "ses_a");
      expect(rows.map((row) => row.partId), contains("kept"));
      expect(blockingRepository.syncStateAdvances, 1, reason: "only the preceding capture committed");
    });

    test("legacy budgeting spans separately delivered image parts of one message", () async {
      final history = createTestChatHistory();
      final firstBytes = Uint8List(3 * 1024 * 1024);
      final secondBytes = Uint8List(3 * 1024 * 1024)..fillRange(0, 16, 7);
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );

      final first = await history.service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "first",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(firstBytes),
            filename: "first.png",
          ),
        ),
      ) as CapturedPartShapes;
      final second = await history.service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "second",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(secondBytes),
            filename: "second.png",
          ),
        ),
      ) as CapturedPartShapes;

      expect(first.inlinePart.attachment, isA<MessageAttachmentInlineImage>());
      expect(
        second.inlinePart.attachment,
        isA<MessageAttachmentMetadata>().having((data) => data.filename, "filename", "second.png"),
        reason: "the released 5 MiB aggregate applies across the whole stored collection",
      );
      expect(second.storedReferencePart.attachment, isA<MessageAttachmentStoredImage>());
    });

    test("retention budgeting spans separately delivered image parts of one message", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );
      for (var index = 0; index < 2; index++) {
        await history.database
            .into(history.database.historyPartsTable)
            .insert(
              HistoryPartsTableCompanion.insert(
                sessionId: "ses_a",
                messageId: "m1",
                partId: "stored-$index",
                orderIndex: index,
                partJson: jsonEncode(
                  _part(
                      id: "stored-$index",
                      attachment: const MessageAttachment.metadata(mime: "image/png", filename: null),
                    ).toJson()
                    ..["attachment"] = {
                      "source": "stored_file",
                      "mime": "image/png",
                      "sha256": "${index + 1}" * 64,
                      "byteLength": 20 * 1024 * 1024,
                    },
                ),
                updatedAt: 1,
              ),
            );
      }

      final captured = await history.service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "overflow",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List(11 * 1024 * 1024)),
            filename: "overflow.png",
          ),
        ),
      ) as CapturedPartShapes;

      expect(captured.inlinePart.attachment, isA<MessageAttachmentMetadata>());
      expect(captured.storedReferencePart.attachment, isA<MessageAttachmentMetadata>());
      final rows = await history.database.chatHistoryDao.getParts(sessionId: "ses_a", messageIds: ["m1"]);
      expect(rows.last.partJson, isNot(contains("stored_file")));
    });

    test("updating an earlier image accounts for later stored siblings", () async {
      final history = createTestChatHistory();
      await history.service.captureMessage(
        sessionId: "ses_a",
        message: _message(id: "m1"),
      );
      for (var index = 0; index < 3; index++) {
        await history.database
            .into(history.database.historyPartsTable)
            .insert(
              HistoryPartsTableCompanion.insert(
                sessionId: "ses_a",
                messageId: "m1",
                partId: "stored-$index",
                orderIndex: index,
                partJson: jsonEncode(
                  _part(
                      id: "stored-$index",
                      attachment: const MessageAttachment.metadata(mime: "image/png", filename: null),
                    ).toJson()
                    ..["attachment"] = {
                      "source": "stored_file",
                      "mime": "image/png",
                      "sha256": "${index + 1}" * 64,
                      "byteLength": 20 * 1024 * 1024,
                    },
                ),
                updatedAt: 1,
              ),
            );
      }

      final captured = await history.service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "stored-0",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List(20 * 1024 * 1024)),
            filename: "updated.png",
          ),
        ),
      ) as CapturedPartShapes;

      expect(captured.inlinePart.attachment, isA<MessageAttachmentMetadata>());
      expect(captured.storedReferencePart.attachment, isA<MessageAttachmentMetadata>());
    });

    test("a failed write returns unavailable and drops the synced marker", () async {
      final history = createTestChatHistory(sessionRepository: _BackfillingSessionRepository());
      // A synced session makes the cleared marker observable rather than
      // merely absent.
      await history.service.backfillSession(sessionId: "ses_a");
      expect((await history.repository.getSyncState(sessionId: "ses_a"))!.syncedAt, isNotNull);
      final service = ChatHistoryService(
        chatHistoryRepository: _FailingWriteRepository(
          chatHistoryDao: history.database.chatHistoryDao,
          attachmentSpillStorage: history.spillStorage,
          archivedSessionStorage: history.archivedStorage,
        ),
        sessionRepository: _BackfillingSessionRepository(),
        attachmentThumbnailBuilder: const AttachmentThumbnailBuilder(),
        bridgeIdProvider: const _BridgeIdProvider("br_test1234"),
      );

      final captured = await service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "p1",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List.fromList([1, 2, 3])),
            filename: "shot.png",
          ),
        ),
      );

      expect(captured, isA<CapturedPartUnavailable>());
      expect((await history.repository.getSyncState(sessionId: "ses_a"))!.syncedAt, isNull);
      expect(
        (await history.database.chatHistoryDao.getParts(sessionId: "ses_a")).map((row) => row.partId),
        isNot(contains("p1")),
      );
    });

    test("a failed large-image write returns a bounded metadata fallback", () async {
      final history = createTestChatHistory();
      final service = ChatHistoryService(
        chatHistoryRepository: _FailingWriteRepository(
          chatHistoryDao: history.database.chatHistoryDao,
          attachmentSpillStorage: history.spillStorage,
          archivedSessionStorage: history.archivedStorage,
        ),
        sessionRepository: _BackfillingSessionRepository(),
        attachmentThumbnailBuilder: const AttachmentThumbnailBuilder(),
        bridgeIdProvider: const _BridgeIdProvider("br_test1234"),
      );

      final captured = await service.capturePartForDelivery(
        sessionId: "ses_a",
        shouldCapture: () => true,
        part: _part(
          id: "large",
          attachment: MessageAttachment.inlineImage(
            mime: "image/png",
            base64: base64Encode(Uint8List(maxInlineMessageAttachmentBytes + 1)),
            filename: "large.png",
          ),
        ),
      ) as CapturedPartUnavailable;

      expect(captured.inlineFallbackPart.attachment, isA<MessageAttachmentMetadata>());
    });
  });
}

Message _message({required String id}) => Message.user(
  promptId: null,
  id: id,
  sessionID: "ses_a",
  agent: null,
  time: const MessageTime(created: 1, completed: null),
);

MessagePart _part({
  required String id,
  MessageAttachment? attachment,
  ToolState? state,
}) => MessagePart(
  id: id,
  sessionID: "ses_a",
  messageID: "m1",
  type: state == null ? MessagePartType.file : MessagePartType.tool,
  text: null,
  tool: state == null ? null : "tool",
  state: state,
  prompt: null,
  description: null,
  agent: null,
  childSessionID: null,
  agentName: null,
  attempt: null,
  retryError: null,
  attachment: attachment,
);

/// Fails the one write the delivery shapes depend on, the way a full or
/// unwritable disk does.
class _FailingWriteRepository({
  required super.chatHistoryDao,
  required super.attachmentSpillStorage,
  required super.archivedSessionStorage,
}) extends ChatHistoryRepository {
  @override
  Future<void> upsertPart({
    required String sessionId,
    required AttachmentStorageScope storageScope,
    required MessagePart part,
    required int updatedAt,
  }) => Future.error(StateError("attachment spill failed"));
}

class _BlockingWriteRepository({
  required final Completer<void> blocker,
  required super.chatHistoryDao,
  required super.attachmentSpillStorage,
  required super.archivedSessionStorage,
}) extends ChatHistoryRepository {
  final Completer<void> _blocked = Completer<void>();
  int syncStateAdvances = 0;

  Future<void> get blocked => _blocked.future;

  @override
  Future<void> upsertPart({
    required String sessionId,
    required AttachmentStorageScope storageScope,
    required MessagePart part,
    required int updatedAt,
  }) async {
    if (part.id == "blocker") {
      _blocked.complete();
      await blocker.future;
    }
    await super.upsertPart(
      sessionId: sessionId,
      storageScope: storageScope,
      part: part,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> advanceSyncState({
    required String sessionId,
    required int watermark,
    required int backendActivityAt,
  }) {
    syncStateAdvances++;
    return super.advanceSyncState(
      sessionId: sessionId,
      watermark: watermark,
      backendActivityAt: backendActivityAt,
    );
  }
}

class _BackfillingSessionRepository() implements SessionRepository {
  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async => [
    MessageWithParts(
      info: _message(id: "m1"),
      parts: [_part(id: "seed")],
    ),
  ];

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async => StoredSession(
    id: sessionId,
    backendSessionId: sessionId,
    pluginId: "opencode",
    projectId: "project-1",
    parentSessionId: null,
    directory: "/tmp/project-1",
    worktreePath: null,
    branchName: null,
    isDedicated: false,
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError("${invocation.memberName} is not part of this test");
}

class const _BridgeIdProvider(@override final String? bridgeId) implements BridgeIdProvider;

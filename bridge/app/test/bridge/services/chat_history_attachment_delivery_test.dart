import "dart:convert";
import "dart:typed_data";

import "package:sesori_bridge/src/api/database/history/chat_history_database.dart";
import "package:sesori_bridge/src/api/models/archived_session_file_dto.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/repositories/chat_history_repository.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";

void main() {
  test("stored delivery projects mixed attachments without changing part or tool order", () async {
    final history = createTestChatHistory();
    final fileBytes = Uint8List.fromList([1, 2, 3]);
    final toolBytes = Uint8List.fromList([4, 5, 6, 7]);
    await history.service.captureMessage(
      sessionId: "ses_a",
      message: _message(id: "m1"),
    );
    await history.service.capturePart(
      sessionId: "ses_a",
      part: _part(
        id: "file",
        messageId: "m1",
        attachment: MessageAttachment.inlineImage(
          mime: "image/png",
          base64: base64Encode(fileBytes),
          filename: "file.png",
        ),
      ),
    );
    await history.service.capturePart(
      sessionId: "ses_a",
      part: _part(
        id: "remote",
        messageId: "m1",
        attachment: const MessageAttachment.remoteUrl(
          mime: "image/jpeg",
          url: "https://example.com/image.jpg",
          filename: "remote.jpg",
        ),
      ),
    );
    await history.service.capturePart(
      sessionId: "ses_a",
      part: _part(
        id: "tool",
        messageId: "m1",
        state: ToolState(
          status: ToolStatus.completed,
          shellCommand: null,
          output: null,
          error: null,
          attachments: [
            const MessageAttachment.metadata(mime: "application/pdf", filename: "report.pdf"),
            MessageAttachment.inlineImage(
              mime: "image/png",
              base64: base64Encode(toolBytes),
              filename: "tool.png",
            ),
          ],
        ),
      ),
    );

    final page = await history.repository.getSessionMessages(
      sessionId: "ses_a",
      storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
      attachmentProjection: const StoredReferenceMessageAttachmentProjection(bridgeId: "br_test1234"),
    );

    expect(page.messages.single.parts.map((part) => part.id), const ["file", "remote", "tool"]);
    expect(
      (page.messages.single.parts[0] as MessagePartFile).attachment,
      isA<MessageAttachmentStoredImage>()
          .having((image) => image.bridgeId, "bridgeId", "br_test1234")
          .having((image) => image.byteLength, "byteLength", fileBytes.length),
    );
    expect((page.messages.single.parts[1] as MessagePartFile).attachment, isA<MessageAttachmentRemoteUrl>());
    final toolAttachments = (page.messages.single.parts[2] as MessagePartTool).state.attachments;
    expect(toolAttachments[0], isA<MessageAttachmentMetadata>());
    expect(
      toolAttachments[1],
      isA<MessageAttachmentStoredImage>().having((image) => image.byteLength, "byteLength", toolBytes.length),
    );
  });

  test("inline delivery applies one legacy budget in attachment order", () async {
    final history = createTestChatHistory();
    final firstBytes = Uint8List(3 * 1024 * 1024);
    final secondBytes = Uint8List(3 * 1024 * 1024);
    await history.service.captureMessage(
      sessionId: "ses_a",
      message: _message(id: "m1"),
    );
    await history.service.capturePart(
      sessionId: "ses_a",
      part: _part(
        id: "first",
        messageId: "m1",
        attachment: MessageAttachment.inlineImage(
          mime: "image/png",
          base64: base64Encode(firstBytes),
          filename: "first.png",
        ),
      ),
    );
    await history.service.capturePart(
      sessionId: "ses_a",
      part: _part(
        id: "second",
        messageId: "m1",
        state: ToolState(
          status: ToolStatus.completed,
          shellCommand: null,
          output: null,
          error: null,
          attachments: [
            MessageAttachment.inlineImage(
              mime: "image/png",
              base64: base64Encode(secondBytes),
              filename: "second.png",
            ),
            const MessageAttachment.metadata(mime: "text/plain", filename: "notes.txt"),
          ],
        ),
      ),
    );

    final page = await history.repository.getSessionMessages(
      sessionId: "ses_a",
      storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
      attachmentProjection: const InlineMessageAttachmentProjection(),
    );

    expect((page.messages.single.parts[0] as MessagePartFile).attachment, isA<MessageAttachmentInlineImage>());
    final toolAttachments = (page.messages.single.parts[1] as MessagePartTool).state.attachments;
    expect(
      toolAttachments[0],
      isA<MessageAttachmentMetadata>().having((metadata) => metadata.filename, "filename", "second.png"),
    );
    expect(toolAttachments[1], isA<MessageAttachmentMetadata>());
  });

  test("stored pages derive old sizes, degrade missing files, and retain pagination", () async {
    final history = createTestChatHistory();
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    final digest = await history.spillStorage.write(
      scope: testAttachmentStorageScope(sessionId: "ses_a"),
      bytes: bytes,
    );
    final missingDigest = "0" * 64;
    await history.service.captureMessage(
      sessionId: "ses_a",
      message: _message(id: "m1"),
    );
    await history.service.captureMessage(
      sessionId: "ses_a",
      message: _message(id: "m2"),
    );
    await _insertStoredPart(
      history: history,
      messageId: "m1",
      partId: "p1",
      digest: digest,
      includeByteLength: false,
    );
    await _insertStoredPart(
      history: history,
      messageId: "m2",
      partId: "p2",
      digest: missingDigest,
      includeByteLength: false,
    );

    final newest = await history.repository.getSessionMessages(
      sessionId: "ses_a",
      storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
      limit: 1,
      attachmentProjection: const StoredReferenceMessageAttachmentProjection(bridgeId: "br_test1234"),
    );
    expect(newest.messages.single.info.id, "m2");
    expect((newest.messages.single.parts.single as MessagePartFile).attachment, isA<MessageAttachmentMetadata>());

    final older = await history.repository.getSessionMessages(
      sessionId: "ses_a",
      storageScope: testAttachmentStorageScope(sessionId: "ses_a"),
      limit: 1,
      before: newest.nextCursor,
      attachmentProjection: const StoredReferenceMessageAttachmentProjection(bridgeId: "br_test1234"),
    );
    expect(older.messages.single.info.id, "m1");
    expect(
      (older.messages.single.parts.single as MessagePartFile).attachment,
      isA<MessageAttachmentStoredImage>().having((image) => image.byteLength, "byteLength", bytes.length),
    );
  });

  test("archived history uses the same stored-reference projection", () async {
    final history = createTestChatHistory();
    final bytes = Uint8List.fromList([1, 2, 3]);
    await history.service.captureMessage(
      sessionId: "ses_a",
      message: _message(id: "m1"),
    );
    await history.service.capturePart(
      sessionId: "ses_a",
      part: _part(
        id: "p1",
        messageId: "m1",
        attachment: MessageAttachment.inlineImage(
          mime: "image/png",
          base64: base64Encode(bytes),
          filename: "archived.png",
        ),
      ),
    );
    await _export(history: history);

    final page = await history.service.getArchivedSessionMessages(
      sessionId: "ses_a",
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
    );

    expect(
      (page!.messages.single.parts.single as MessagePartFile).attachment,
      isA<MessageAttachmentStoredImage>()
          .having((image) => image.bridgeId, "bridgeId", "br_test1234")
          .having((image) => image.byteLength, "byteLength", bytes.length),
    );
  });

  test("stored delivery fails explicitly before bridge registration", () async {
    final history = createTestChatHistory(bridgeIdProvider: const _BridgeIdProvider(null));
    await history.service.captureMessage(
      sessionId: "ses_a",
      message: _message(id: "m1"),
    );
    await history.service.capturePart(
      sessionId: "ses_a",
      part: _part(
        id: "p1",
        messageId: "m1",
        attachment: MessageAttachment.inlineImage(
          mime: "image/png",
          base64: base64Encode(Uint8List.fromList([1])),
          filename: null,
        ),
      ),
    );
    await _export(history: history);

    expect(
      () => history.service.getArchivedSessionMessages(
        sessionId: "ses_a",
        attachmentDelivery: MessageAttachmentDelivery.storedReference,
      ),
      throwsStateError,
    );
  });
}

Future<void> _insertStoredPart({
  required TestChatHistory history,
  required String messageId,
  required String partId,
  required String digest,
  required bool includeByteLength,
}) {
  final json = _part(
    id: partId,
    messageId: messageId,
    attachment: const MessageAttachment.metadata(mime: "image/png", filename: "old.png"),
  ).toJson();
  json["attachment"] = {
    "source": "stored_file",
    "mime": "image/png",
    "filename": "old.png",
    "sha256": digest,
    if (includeByteLength) "byteLength": 1,
  };
  return history.database
      .into(history.database.historyPartsTable)
      .insert(
        HistoryPartsTableCompanion.insert(
          sessionId: "ses_a",
          messageId: messageId,
          partId: partId,
          orderIndex: 0,
          partJson: jsonEncode(json),
          updatedAt: 1,
        ),
      );
}

Future<void> _export({required TestChatHistory history}) {
  return history.repository.exportSession(
    session: const StoredSession(
      id: "ses_a",
      backendSessionId: "ses_a",
      pluginId: "opencode",
      projectId: "project-a",
      parentSessionId: null,
      directory: "/tmp/project-a",
      worktreePath: null,
      branchName: null,
      isDedicated: false,
      archivedAt: 1,
      baseBranch: null,
      baseCommit: null,
    ),
    title: null,
    createdAt: 1,
    updatedAt: 1,
    archivedAt: 1,
    completeness: ArchivedSessionCompleteness.complete,
  );
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
  required String messageId,
  MessageAttachment? attachment,
  ToolState? state,
}) => state == null
    ? MessagePart.file(
        id: id,
        sessionID: "ses_a",
        messageID: messageId,
        attachment: attachment ?? const MessageAttachment.unknown(),
      )
    : MessagePart.tool(id: id, sessionID: "ses_a", messageID: messageId, tool: "tool", state: state);

class const _BridgeIdProvider(@override final String? bridgeId) implements BridgeIdProvider;

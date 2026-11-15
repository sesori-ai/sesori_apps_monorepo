import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

class _MockFilePreviewRepository() extends Mock implements FilePreviewRepository;

const _sessionId = "ses_1";
const _reportPath = "/uploads/ses_1/2026-11-01-abc/report.pdf";
const _notesPath = "/uploads/ses_1/2026-10-01-def/notes.txt";

const _stored = MessageAttachment.storedImage(
  attachmentId: "attachment-1",
  bridgeId: "bridge-1",
  mime: "image/png",
  filename: "shot.png",
  byteLength: 3,
);
const _pruned = MessageAttachment.storedImage(
  attachmentId: "attachment-2",
  bridgeId: "bridge-1",
  mime: "image/png",
  filename: "old.png",
  byteLength: 3,
);

MessageWithParts _message({required List<MessagePart> parts}) => MessageWithParts(
  info: const Message.user(
    id: "msg_1",
    sessionID: _sessionId,
    agent: null,
    time: null,
    promptId: null,
    invocation: null,
    handoff: null,
  ),
  parts: parts,
);

MessagePart _text(String text) =>
    MessagePart.text(id: "part_$text", sessionID: _sessionId, messageID: "msg_1", text: text);

MessagePart _file(MessageAttachment attachment) => MessagePart.file(
  id: "file_${attachment.hashCode}",
  sessionID: _sessionId,
  messageID: "msg_1",
  attachment: attachment,
);

void main() {
  late _MockMessageImageRepository images;
  late _MockFilePreviewRepository previews;
  late MessageComposerRestoreService service;
  final pngBytes = Uint8List.fromList(const [1, 2, 3]);

  setUpAll(() {
    registerFallbackValue(const MessageAttachment.unknown());
  });

  setUp(() {
    images = _MockMessageImageRepository();
    previews = _MockFilePreviewRepository();
    service = MessageComposerRestoreService(images: images, filePreviews: previews);
    when(() => images.loadWhole(sessionId: _sessionId, attachment: _stored)).thenAnswer(
      (_) async =>
          MessageImageLoadSuccess(bytes: pngBytes, mime: "image/png", actionFilename: "shot.png", originalUri: null),
    );
    when(
      () => images.loadWhole(sessionId: _sessionId, attachment: _pruned),
    ).thenAnswer((_) async => const MessageImageLoadRejected());
    when(() => previews.load(path: _reportPath)).thenAnswer((_) async => FilePreviewPdfContent(bytes: Uint8List(0)));
    when(() => previews.load(path: _notesPath)).thenAnswer(
      (_) async => const FilePreviewContentUnavailable(reason: FilePreviewUnavailableReason.missing),
    );
  });

  test("brings back the text without its notes, its images, and its saved files by path", () async {
    final restored = await service.restore(
      sessionId: _sessionId,
      message: _message(
        parts: [
          _text("Compare these"),
          _text(savedFileNote(name: "report.pdf", path: _reportPath)),
          _file(_stored),
        ],
      ),
    );

    expect(restored.draft, ComposerDraft.typed(text: "Compare these"));
    expect(restored.attachments, hasLength(2));
    expect(
      restored.attachments.first,
      isA<ComposerImageAttachment>()
          .having((image) => image.bytes, "bytes", same(pngBytes))
          .having((image) => image.mime, "mime", "image/png")
          .having((image) => image.filename, "filename", "shot.png"),
    );
    expect(
      restored.attachments.last,
      isA<ComposerHostFileAttachment>()
          .having((file) => file.path, "path", _reportPath)
          .having((file) => file.filename, "filename", "report.pdf"),
    );
    expect(restored.leftOutCount, 0);
  });

  test("restores a message that held only attachments with an empty draft", () async {
    final restored = await service.restore(
      sessionId: _sessionId,
      message: _message(
        parts: [
          _text(savedFileNote(name: "report.pdf", path: _reportPath)),
          _file(_stored),
        ],
      ),
    );

    expect(restored.draft.text, isEmpty);
    expect(restored.attachments.map((attachment) => attachment.filename), ["shot.png", "report.pdf"]);
    expect(restored.leftOutCount, 0);
  });

  test("leaves out and counts a swept upload and an image the bridge can no longer serve", () async {
    final restored = await service.restore(
      sessionId: _sessionId,
      message: _message(
        parts: [
          _text('Again\n\n${savedFileNote(name: "notes.txt", path: _notesPath)}'),
          _text(savedFileNote(name: "report.pdf", path: _reportPath)),
          _file(_stored),
          _file(_pruned),
        ],
      ),
    );

    expect(restored.draft.text, "Again");
    expect(restored.attachments.map((attachment) => attachment.filename), ["shot.png", "report.pdf"]);
    expect(restored.leftOutCount, 2);
  });

  test("keeps a saved file it could not check, since only the bridge knows whether it is gone", () async {
    when(() => previews.load(path: _notesPath)).thenAnswer(
      (_) async => FilePreviewFailed(innerError: StateError("offline"), stackTrace: StackTrace.empty),
    );

    final restored = await service.restore(
      sessionId: _sessionId,
      message: _message(
        parts: [_text(savedFileNote(name: "notes.txt", path: _notesPath))],
      ),
    );

    expect(
      restored.attachments.single,
      isA<ComposerHostFileAttachment>().having((file) => file.path, "path", _notesPath),
    );
    expect(restored.leftOutCount, 0);
  });

  test("counts an attachment it cannot show as left out, but not one the transcript hides", () async {
    const metadata = MessageAttachment.metadata(mime: "application/pdf", filename: "spec.pdf");
    when(
      () => images.loadWhole(sessionId: _sessionId, attachment: metadata),
    ).thenAnswer((_) async => const MessageImageLoadUnsupported());

    final restored = await service.restore(
      sessionId: _sessionId,
      message: _message(parts: [_text("hi"), _file(metadata), _file(const MessageAttachment.unknown())]),
    );

    expect(restored.draft.text, "hi");
    expect(restored.attachments, isEmpty);
    expect(restored.leftOutCount, 1);
    verifyNever(() => images.loadWhole(sessionId: _sessionId, attachment: const MessageAttachment.unknown()));
  });
}

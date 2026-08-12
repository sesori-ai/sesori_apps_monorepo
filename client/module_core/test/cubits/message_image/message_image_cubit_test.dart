import "dart:async";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockMessageImageRepository extends Mock implements MessageImageRepository;

const _stored = MessageAttachment.storedImage(
  attachmentId: "attachment-1",
  bridgeId: "bridge-1",
  mime: "image/png",
  filename: "image.png",
  byteLength: 8,
);

void main() {
  late _MockMessageImageRepository repository;

  setUpAll(() {
    registerFallbackValue(const MessageAttachment.unknown());
    registerFallbackValue(SessionAttachmentRendition.thumbnail);
  });

  setUp(() {
    repository = _MockMessageImageRepository();
    when(() => repository.canLoad(attachment: any(named: "attachment"))).thenReturn(true);
    when(() => repository.canLoadOriginal(attachment: any(named: "attachment"))).thenReturn(true);
  });

  test("owns initial stored thumbnail load and leaves original available", () async {
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => MessageImageLoadSuccess(
        bytes: Uint8List.fromList(const [1]),
        mime: "image/png",
        actionFilename: "image.png",
        originalUri: null,
      ),
    );

    final cubit = MessageImageCubit(repository: repository, sessionId: "session-1", attachment: _stored);
    addTearDown(cubit.close);

    expect(cubit.state.preview, isA<MessageImagePreviewLoading>());
    expect(cubit.state.original, isA<MessageImageOriginalAvailable>());
    final loaded = await cubit.stream.firstWhere((state) => state.preview is MessageImagePreviewLoaded);
    expect((loaded.preview as MessageImagePreviewLoaded).bytes, [1]);
    expect(loaded.original, isA<MessageImageOriginalAvailable>());
    verifyNever(
      () => repository.load(
        sessionId: any(named: "sessionId"),
        attachment: any(named: "attachment"),
        rendition: SessionAttachmentRendition.original,
      ),
    );
  });

  test("loads original only on intent while preserving preview through load and failure", () async {
    final original = Completer<MessageImageLoadResult>();
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => MessageImageLoadSuccess(
        bytes: Uint8List.fromList(const [1]),
        mime: "image/png",
        actionFilename: "image.png",
        originalUri: null,
      ),
    );
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.original,
      ),
    ).thenAnswer((_) => original.future);
    final cubit = MessageImageCubit(repository: repository, sessionId: "session-1", attachment: _stored);
    addTearDown(cubit.close);
    await cubit.stream.firstWhere((state) => state.preview is MessageImagePreviewLoaded);
    final preview = cubit.state.preview;

    final load = cubit.loadOriginal();
    expect(cubit.state.preview, same(preview));
    expect(cubit.state.original, isA<MessageImageOriginalLoading>());
    final cause = StateError("failed");
    final stackTrace = StackTrace.current;
    original.complete(MessageImageLoadFailure(cause: cause, stackTrace: stackTrace));
    await load;

    expect(cubit.state.preview, same(preview));
    final failed = cubit.state.original as MessageImageOriginalFailed;
    expect(failed.cause, same(cause));
    expect(failed.stackTrace, same(stackTrace));
  });

  test("load intents do not duplicate in-flight preview or an already loaded original", () async {
    final preview = Completer<MessageImageLoadResult>();
    var previewRequests = 0;
    var originalRequests = 0;
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) {
      previewRequests++;
      return preview.future;
    });
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.original,
      ),
    ).thenAnswer((_) async {
      originalRequests++;
      return MessageImageLoadSuccess(
        bytes: Uint8List.fromList(const [2]),
        mime: "image/png",
        actionFilename: "image.png",
        originalUri: null,
      );
    });
    final cubit = MessageImageCubit(repository: repository, sessionId: "session-1", attachment: _stored);
    addTearDown(cubit.close);

    await cubit.loadPreview();
    expect(previewRequests, 1);
    preview.complete(
      MessageImageLoadSuccess(
        bytes: Uint8List.fromList(const [1]),
        mime: "image/png",
        actionFilename: "image.png",
        originalUri: null,
      ),
    );
    await cubit.stream.firstWhere((state) => state.preview is MessageImagePreviewLoaded);

    await cubit.loadOriginal();
    await cubit.retryOriginal();
    expect(originalRequests, 1);
    expect(cubit.state.original, isA<MessageImageOriginalLoaded>());
  });

  test("retry intents reload independent state machines", () async {
    var previewRequests = 0;
    var originalRequests = 0;
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) async {
      previewRequests++;
      return const MessageImageLoadRejected();
    });
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: _stored,
        rendition: SessionAttachmentRendition.original,
      ),
    ).thenAnswer((_) async {
      originalRequests++;
      return const MessageImageLoadRejected();
    });
    final cubit = MessageImageCubit(repository: repository, sessionId: "session-1", attachment: _stored);
    addTearDown(cubit.close);
    await cubit.stream.firstWhere((state) => state.preview is MessageImagePreviewRejected);

    await cubit.retryOriginal();
    expect(cubit.state.preview, isA<MessageImagePreviewRejected>());
    expect(cubit.state.original, isA<MessageImageOriginalRejected>());
    await cubit.retryPreview();

    expect(previewRequests, 2);
    expect(originalRequests, 1);
    expect(cubit.state.original, isA<MessageImageOriginalRejected>());
  });

  test("inline preview loads while original is coherently unavailable", () async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgo=",
      filename: "image.png",
    );
    when(() => repository.canLoadOriginal(attachment: attachment)).thenReturn(false);
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: attachment,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => MessageImageLoadSuccess(
        bytes: Uint8List.fromList(const [1]),
        mime: "image/png",
        actionFilename: "image.png",
        originalUri: null,
      ),
    );
    final cubit = MessageImageCubit(repository: repository, sessionId: "session-1", attachment: attachment);
    addTearDown(cubit.close);

    final loaded = await cubit.stream.firstWhere((state) => state.preview is MessageImagePreviewLoaded);
    expect(loaded.original, isA<MessageImageOriginalUnavailable>());
    await cubit.loadOriginal();
    expect(cubit.state.original, isA<MessageImageOriginalUnavailable>());
  });
}

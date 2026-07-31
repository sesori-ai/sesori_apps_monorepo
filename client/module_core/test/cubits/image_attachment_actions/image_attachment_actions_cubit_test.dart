import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

final class _FakeImageSaver implements ImageSaver {
  Uint8List? bytes;
  String? mime;
  String? filename;
  ImageSaveResult result = ImageSaveResult.saved;

  @override
  Future<ImageSaveResult> saveImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
  }) async {
    this.bytes = bytes;
    this.mime = mime;
    this.filename = filename;
    return result;
  }
}

final class _FakeImageClipboard implements ImageClipboard {
  Uint8List? bytes;
  Object? error;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {
    final error = this.error;
    if (error != null) throw error;
    this.bytes = bytes;
  }
}

final class _FakeImageSharer implements ImageSharer {
  Uint8List? bytes;
  String? mime;
  String? filename;
  ImageShareOrigin? origin;

  @override
  Future<void> shareImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
    required ImageShareOrigin? origin,
  }) async {
    this.bytes = bytes;
    this.mime = mime;
    this.filename = filename;
    this.origin = origin;
  }
}

void main() {
  late Uint8List bytes;
  late _FakeImageSaver imageSaver;
  late _FakeImageClipboard imageClipboard;
  late _FakeImageSharer imageSharer;

  setUp(() {
    bytes = Uint8List.fromList(const [1, 2, 3]);
    imageSaver = _FakeImageSaver();
    imageClipboard = _FakeImageClipboard();
    imageSharer = _FakeImageSharer();
  });

  ImageAttachmentActionsCubit buildCubit() => ImageAttachmentActionsCubit(
    imageSaver: imageSaver,
    imageClipboard: imageClipboard,
    imageSharer: imageSharer,
    bytes: bytes,
    mime: "image/png",
    actionFilename: "unsafe.png",
  );

  test("copies the retained image bytes", () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);
    final states = <ImageAttachmentActionsState>[];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(subscription.cancel);

    await cubit.copy();
    await Future<void>.delayed(Duration.zero);

    expect(identical(imageClipboard.bytes, bytes), isTrue);
    expect(states, [isA<ImageAttachmentActionRunning>(), isA<ImageAttachmentCopied>()]);
  });

  test("saves the repository-provided action filename unchanged", () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.save();

    expect(identical(imageSaver.bytes, bytes), isTrue);
    expect(imageSaver.mime, "image/png");
    expect(imageSaver.filename, "unsafe.png");
    expect(cubit.state, isA<ImageAttachmentSaved>());
  });

  test("returns to idle when desktop file saving is cancelled", () async {
    imageSaver.result = ImageSaveResult.cancelled;
    final cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.save();

    expect(cubit.state, isA<ImageAttachmentActionsIdle>());
  });

  test("reports save access denial without naming a platform destination", () async {
    imageSaver.result = ImageSaveResult.accessDenied;
    final cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.save();

    expect(cubit.state, isA<ImageAttachmentSaveAccessDenied>());
  });

  test("shares the retained bytes and platform origin", () async {
    const origin = ImageShareOrigin(left: 1, top: 2, width: 3, height: 4);
    final cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.share(origin: origin);

    expect(identical(imageSharer.bytes, bytes), isTrue);
    expect(imageSharer.mime, "image/png");
    expect(imageSharer.filename, "unsafe.png");
    expect(identical(imageSharer.origin, origin), isTrue);
    expect(cubit.state, isA<ImageAttachmentActionsIdle>());
  });

  test("retains the clipboard error in the failure state", () async {
    final error = StateError("clipboard unavailable");
    imageClipboard.error = error;
    final cubit = buildCubit();
    addTearDown(cubit.close);

    await cubit.copy();

    final state = cubit.state as ImageAttachmentCopyFailed;
    expect(identical(state.cause, error), isTrue);
  });
}

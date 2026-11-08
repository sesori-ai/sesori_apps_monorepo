import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:image_picker/image_picker.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_composer_image_picker.dart";
import "package:sesori_mobile/core/platform/platform_image_shrinker.dart";

class MockImagePicker() extends Mock implements ImagePicker;

class _MockConnectionService() extends Mock implements ConnectionService;

class _MockActiveBridgeLocality() extends Mock implements ActiveBridgeLocality;

/// Stands in for the platform decoder: returns [result] for any input, or the
/// input untouched when [result] is unset, and records what it was given.
class _FakeShrinker() implements PlatformImageShrinker {
  final shrunk = <Uint8List>[];
  Uint8List? Function(Uint8List bytes) result = (bytes) => bytes;

  @override
  Future<Uint8List?> shrink({required Uint8List bytes}) async {
    shrunk.add(bytes);
    return result(bytes);
  }
}

void main() {
  late MockImagePicker imagePicker;
  late _FakeShrinker shrinker;
  late FlutterComposerImagePicker picker;
  late ComposerAttachmentDispatcher attachmentDispatcher;

  setUp(() {
    imagePicker = MockImagePicker();
    shrinker = _FakeShrinker();
    picker = FlutterComposerImagePicker(picker: imagePicker, shrinker: shrinker);
    attachmentDispatcher = ComposerAttachmentDispatcher(
      filePicker: picker,
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      hostFiles: HostFileRepository(client: const HostFileClient()),
      connectionService: _MockConnectionService(),
      locality: _MockActiveBridgeLocality(),
    );
  });

  void stubPick(XFile? file) {
    when(
      () => imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: any(named: "maxWidth"),
        maxHeight: any(named: "maxHeight"),
        imageQuality: any(named: "imageQuality"),
        requestFullMetadata: any(named: "requestFullMetadata"),
      ),
    ).thenAnswer((_) async => file);
  }

  Future<ComposerAttachment?> pickAttachment() async {
    final outcome = await attachmentDispatcher.pick(attachmentsSupported: true, stagedAttachmentBytes: 0);
    return outcome?.attachments.single;
  }

  Uint8List jpegBytes([int length = 16]) {
    final bytes = Uint8List(length);
    bytes.setAll(0, const [0xFF, 0xD8, 0xFF]);
    return bytes;
  }

  test("a dismissed picker stages nothing", () async {
    stubPick(null);
    expect(await pickAttachment(), isNull);
  });

  test("clipboard bytes use shared validation and have no filename", () async {
    final bytes = jpegBytes();

    final attachment = await attachmentDispatcher.attachmentFromBytes(bytes: bytes, filename: null);

    expect(attachment.mime, "image/jpeg");
    expect(attachment.bytes, same(bytes));
    expect(attachment.filename, isNull);
  });

  test("reads the selected file while shared validation keeps its filename", () async {
    // A path-backed XFile, like the real picker returns — XFile.fromData does
    // not consistently surface a platform filename.
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
    final file = File("${Directory.systemTemp.createTempSync("picker_test").path}/shot.png")..writeAsBytesSync(png);
    addTearDown(() => file.parent.deleteSync(recursive: true));
    stubPick(XFile(file.path));

    final attachment = await pickAttachment();

    if (attachment == null) fail("no image was picked");
    expect(attachment.mime, "image/png");
    expect(attachment.filename, "shot.png");
    expect(attachment.bytes, png);
  });

  test("Android asks for the original image, so an animated GIF stays animated", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    stubPick(null);

    await pickAttachment();

    verify(() => imagePicker.pickImage(source: ImageSource.gallery, requestFullMetadata: false)).called(1);
  });

  test("Android hands a GIF over untouched so it stays animated", () async {
    final gif = Uint8List.fromList([...latin1.encode("GIF89a"), 1, 0, 1, 0, 0, 0]);
    stubPick(XFile.fromData(gif, name: "anim.gif"));

    final attachment = await pickAttachment();

    expect(attachment?.mime, "image/gif");
    expect(attachment?.bytes, gif);
    expect(shrinker.shrunk, isEmpty);
  });

  test("Android shrinks any other photo with the platform decoder and names it after the result", () async {
    final heic = Uint8List.fromList([0, 0, 0, 24, ...latin1.encode("ftypheic"), 0, 0, 0, 0]);
    final jpeg = jpegBytes();
    shrinker.result = (_) => jpeg;
    final file = File("${Directory.systemTemp.createTempSync("picker_test").path}/IMG_0001.HEIC")
      ..writeAsBytesSync(heic);
    addTearDown(() => file.parent.deleteSync(recursive: true));
    stubPick(XFile(file.path));

    final attachment = await pickAttachment();

    expect(shrinker.shrunk, [heic]);
    expect(attachment?.mime, "image/jpeg");
    expect(attachment?.bytes, jpeg);
    expect(attachment?.filename, "IMG_0001.jpg");
  });

  test("a photo the platform can't decode is turned away as unsupported", () async {
    shrinker.result = (_) => null;
    stubPick(XFile.fromData(jpegBytes(), name: "photo.heic"));

    expect(pickAttachment, throwsA(isA<UnsupportedAttachmentImageError>()));
  });

  test("iOS applies the shared size rule natively", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    stubPick(XFile.fromData(jpegBytes(), name: "photo.jpg"));

    await pickAttachment();

    expect(shrinker.shrunk, isEmpty);

    verify(
      () => imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      ),
    ).called(1);
  });

  test("re-encoded jpeg content sniffs as jpeg regardless of extension", () async {
    stubPick(XFile.fromData(jpegBytes(), name: "photo.heic"));

    final attachment = await pickAttachment();

    expect(attachment?.mime, "image/jpeg");
  });

  test("unsupported selected content is rejected by shared validation", () async {
    stubPick(XFile.fromData(Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]), name: "blob.bin"));

    expect(pickAttachment, throwsA(isA<UnsupportedAttachmentImageError>()));
  });

  test("an image over the outbound composer limit is rejected", () async {
    stubPick(XFile.fromData(jpegBytes(maxComposerPromptAttachmentBytes + 1), name: "huge.jpg"));

    expect(pickAttachment, throwsA(isA<AttachmentTooLargeError>()));
  });
}

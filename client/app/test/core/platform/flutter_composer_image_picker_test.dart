import "dart:io";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:image_picker/image_picker.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_composer_image_picker.dart";

class MockImagePicker() extends Mock implements ImagePicker;

void main() {
  late MockImagePicker imagePicker;
  late FlutterComposerImagePicker picker;
  late ComposerAttachmentDispatcher attachmentDispatcher;

  setUp(() {
    imagePicker = MockImagePicker();
    picker = FlutterComposerImagePicker(picker: imagePicker);
    attachmentDispatcher = ComposerAttachmentDispatcher(imagePicker: picker);
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

  Uint8List jpegBytes([int length = 16]) {
    final bytes = Uint8List(length);
    bytes.setAll(0, const [0xFF, 0xD8, 0xFF]);
    return bytes;
  }

  test("a dismissed picker stages nothing", () async {
    stubPick(null);
    expect(await attachmentDispatcher.pickImage(), isNull);
  });

  test("clipboard bytes use shared validation and have no filename", () {
    final bytes = jpegBytes();

    final attachment = attachmentDispatcher.attachmentFromBytes(bytes: bytes, filename: null);

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

    final attachment = await attachmentDispatcher.pickImage();

    expect(attachment!.mime, "image/png");
    expect(attachment.filename, "shot.png");
    expect(attachment.bytes, png);
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

    final attachment = await attachmentDispatcher.pickImage();

    expect(attachment!.mime, "image/jpeg");
  });

  test("unsupported selected content is rejected by shared validation", () async {
    stubPick(XFile.fromData(Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]), name: "blob.bin"));

    expect(attachmentDispatcher.pickImage, throwsA(isA<UnsupportedAttachmentImageError>()));
  });

  test("an image over the outbound composer limit is rejected", () async {
    stubPick(XFile.fromData(jpegBytes(maxComposerPromptAttachmentBytes + 1), name: "huge.jpg"));

    expect(attachmentDispatcher.pickImage, throwsA(isA<AttachmentTooLargeError>()));
  });
}

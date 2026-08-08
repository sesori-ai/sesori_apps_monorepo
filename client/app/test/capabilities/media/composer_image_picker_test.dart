import "dart:io";
import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:image_picker/image_picker.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/media/composer_image_picker.dart";

class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  late MockImagePicker imagePicker;
  late ComposerImagePicker picker;

  setUp(() {
    imagePicker = MockImagePicker();
    picker = ComposerImagePicker(picker: imagePicker);
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
    expect(await picker.pickImage(), isNull);
  });

  test("clipboard bytes use the same validation and have no filename", () {
    final bytes = jpegBytes();

    final attachment = picker.attachmentFromBytes(bytes: bytes, filename: null);

    expect(attachment.mime, "image/jpeg");
    expect(attachment.bytes, same(bytes));
    expect(attachment.filename, isNull);
  });

  test("sniffs the mime from content and keeps the picker filename", () async {
    // A path-backed XFile, like the real picker returns — XFile.fromData does
    // not surface a name.
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
    final file = File("${Directory.systemTemp.createTempSync("picker_test").path}/shot.png")
      ..writeAsBytesSync(png);
    addTearDown(() => file.parent.deleteSync(recursive: true));
    stubPick(XFile(file.path));

    final attachment = await picker.pickImage();

    expect(attachment!.mime, "image/png");
    expect(attachment.filename, "shot.png");
    expect(attachment.bytes, png);
  });

  test("re-encoded jpeg content sniffs as jpeg regardless of extension", () async {
    stubPick(XFile.fromData(jpegBytes(), name: "photo.heic"));

    final attachment = await picker.pickImage();

    expect(attachment!.mime, "image/jpeg");
  });

  test("a truncated png signature is rejected, matching the renderer's check", () async {
    stubPick(XFile.fromData(Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]), name: "cut.png"));

    expect(picker.pickImage, throwsA(isA<UnsupportedAttachmentImageError>()));
  });

  test("heif content is rejected — the client's inline renderer cannot decode it", () async {
    final heic = Uint8List.fromList([
      0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, // ....ftypheic
      ...List<int>.filled(12, 0),
    ]);
    stubPick(XFile.fromData(heic, name: "photo.heic"));

    expect(picker.pickImage, throwsA(isA<UnsupportedAttachmentImageError>()));
  });

  test("unrecognized content is rejected instead of mislabeled", () async {
    stubPick(XFile.fromData(Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]), name: "blob.bin"));

    expect(picker.pickImage, throwsA(isA<UnsupportedAttachmentImageError>()));
  });

  test("an image over the outbound composer limit is rejected", () async {
    stubPick(XFile.fromData(jpegBytes(maxComposerPromptAttachmentBytes + 1), name: "huge.jpg"));

    expect(picker.pickImage, throwsA(isA<AttachmentTooLargeError>()));
  });

  test("an exactly-boundary image passes the outbound composer check", () async {
    final bytes = jpegBytes(maxComposerPromptAttachmentBytes);
    stubPick(XFile.fromData(bytes, name: "big.jpg"));

    final attachment = await picker.pickImage();

    expect(attachment!.bytes.length, bytes.length);
  });
}

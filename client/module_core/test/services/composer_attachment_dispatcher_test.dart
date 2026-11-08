import "dart:math" as math;
import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _StubComposerImagePicker({required final ComposerPickedImage? result}) implements ComposerImagePicker {
  @override
  Future<ComposerPickedImage?> pickImage() async => result;
}

void main() {
  Uint8List bytesWithPrefix({required List<int> prefix, int length = 16}) {
    final bytes = Uint8List(length);
    bytes.setAll(0, prefix);
    return bytes;
  }

  ComposerAttachmentDispatcher dispatcherFor({required ComposerPickedImage? picked}) => ComposerAttachmentDispatcher(
    imagePicker: _StubComposerImagePicker(result: picked),
    downscaleBuilder: const ComposerImageDownscaleBuilder(),
  );

  group("ComposerAttachmentDispatcher", () {
    test("returns null when selection is dismissed", () async {
      expect(await dispatcherFor(picked: null).pickImage(), isNull);
    });

    test("validates picked bytes and normalizes the filename", () async {
      final bytes = bytesWithPrefix(prefix: const [0xFF, 0xD8, 0xFF]);
      final dispatcher = dispatcherFor(
        picked: ComposerPickedImage(bytes: bytes, filename: "  photo.jpg  "),
      );

      final attachment = await dispatcher.pickImage() ?? fail("no image picked");

      expect(attachment.mime, "image/jpeg");
      expect(attachment.bytes, same(bytes));
      expect(attachment.filename, "photo.jpg");
    });

    test("recognizes supported composer image signatures", () async {
      final dispatcher = dispatcherFor(picked: null);
      final cases = <(List<int>, String)>[
        (const [0xFF, 0xD8, 0xFF], "image/jpeg"),
        (const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "image/png"),
        ("GIF89a".codeUnits, "image/gif"),
        (const [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50], "image/webp"),
        (const [0x42, 0x4D], "image/bmp"),
      ];

      for (final (prefix, mime) in cases) {
        final attachment = await dispatcher.attachmentFromBytes(
          bytes: bytesWithPrefix(prefix: prefix),
          filename: "image",
        );
        expect(attachment.mime, mime);
      }
    });

    test("converts an empty filename to null", () async {
      final attachment = await dispatcherFor(picked: null).attachmentFromBytes(
        bytes: bytesWithPrefix(prefix: const [0xFF, 0xD8, 0xFF]),
        filename: "   ",
      );

      expect(attachment.filename, isNull);
    });

    test("rejects unsupported bytes", () async {
      await expectLater(
        dispatcherFor(picked: null).attachmentFromBytes(
          bytes: Uint8List.fromList(List<int>.generate(16, (index) => index)),
          filename: "blob.bin",
        ),
        throwsA(isA<UnsupportedAttachmentImageError>()),
      );
    });

    test("rejects bytes that stay above the outbound limit", () async {
      // Not decodable, so the downscale keeps the original and the limit applies.
      final bytes = bytesWithPrefix(
        prefix: const [0xFF, 0xD8, 0xFF],
        length: maxComposerPromptAttachmentBytes + 1,
      );

      await expectLater(
        dispatcherFor(picked: null).attachmentFromBytes(bytes: bytes, filename: "huge.jpg"),
        throwsA(isA<AttachmentTooLargeError>()),
      );
    });

    test("stages an oversized image as a downscaled JPEG with a matching filename", () async {
      final random = math.Random(7);
      final source = image.Image(width: 2600, height: 900);
      for (final pixel in source) {
        pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
      }
      final png = image.encodePng(source, level: 1);
      final dispatcher = dispatcherFor(
        picked: ComposerPickedImage(bytes: png, filename: "screenshot.png"),
      );

      final attachment = await dispatcher.pickImage() ?? fail("no image picked");

      expect(attachment.mime, "image/jpeg");
      expect(attachment.filename, "screenshot.jpg");
      expect(attachment.bytes.length, lessThan(png.length));
    });
  });
}

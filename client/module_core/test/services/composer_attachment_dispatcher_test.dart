import "dart:typed_data";

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

  group("ComposerAttachmentDispatcher", () {
    test("returns null when selection is dismissed", () async {
      final dispatcher = ComposerAttachmentDispatcher(imagePicker: _StubComposerImagePicker(result: null));

      expect(await dispatcher.pickImage(), isNull);
    });

    test("validates picked bytes and normalizes the filename", () async {
      final bytes = bytesWithPrefix(prefix: const [0xFF, 0xD8, 0xFF]);
      final dispatcher = ComposerAttachmentDispatcher(
        imagePicker: _StubComposerImagePicker(
          result: ComposerPickedImage(bytes: bytes, filename: "  photo.jpg  "),
        ),
      );

      final attachment = await dispatcher.pickImage();

      expect(attachment!.mime, "image/jpeg");
      expect(attachment.bytes, same(bytes));
      expect(attachment.filename, "photo.jpg");
    });

    test("recognizes supported composer image signatures", () {
      final dispatcher = ComposerAttachmentDispatcher(imagePicker: _StubComposerImagePicker(result: null));
      final cases = <(List<int>, String)>[
        (const [0xFF, 0xD8, 0xFF], "image/jpeg"),
        (const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "image/png"),
        ("GIF89a".codeUnits, "image/gif"),
        (const [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50], "image/webp"),
        (const [0x42, 0x4D], "image/bmp"),
      ];

      for (final (prefix, mime) in cases) {
        final attachment = dispatcher.attachmentFromBytes(
          bytes: bytesWithPrefix(prefix: prefix),
          filename: "image",
        );
        expect(attachment.mime, mime);
      }
    });

    test("converts an empty filename to null", () {
      final dispatcher = ComposerAttachmentDispatcher(imagePicker: _StubComposerImagePicker(result: null));

      final attachment = dispatcher.attachmentFromBytes(
        bytes: bytesWithPrefix(prefix: const [0xFF, 0xD8, 0xFF]),
        filename: "   ",
      );

      expect(attachment.filename, isNull);
    });

    test("rejects unsupported bytes", () {
      final dispatcher = ComposerAttachmentDispatcher(imagePicker: _StubComposerImagePicker(result: null));

      expect(
        () => dispatcher.attachmentFromBytes(
          bytes: Uint8List.fromList(List<int>.generate(16, (index) => index)),
          filename: "blob.bin",
        ),
        throwsA(isA<UnsupportedAttachmentImageError>()),
      );
    });

    test("rejects bytes above the outbound limit", () {
      final dispatcher = ComposerAttachmentDispatcher(imagePicker: _StubComposerImagePicker(result: null));
      final bytes = bytesWithPrefix(
        prefix: const [0xFF, 0xD8, 0xFF],
        length: maxComposerPromptAttachmentBytes + 1,
      );

      expect(
        () => dispatcher.attachmentFromBytes(bytes: bytes, filename: "huge.jpg"),
        throwsA(isA<AttachmentTooLargeError>()),
      );
    });
  });
}

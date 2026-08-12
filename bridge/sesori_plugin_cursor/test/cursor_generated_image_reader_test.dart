import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/src/repositories/cursor_generated_image_reader.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageBytes;
import "package:test/test.dart";

void main() {
  group("CursorGeneratedImageReader", () {
    const reader = CursorGeneratedImageReader();

    // Microsecond-stamped names: parallel worktrees run this suite against the
    // same systemTemp concurrently, so fixed names can race.
    File tempFile(String prefix) {
      final file = File(
        "${Directory.systemTemp.path}/$prefix-${DateTime.now().microsecondsSinceEpoch}.png",
      );
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      return file;
    }

    test("maps a bounded local PNG into an inline image block", () async {
      final file = tempFile("cursor-generated-image");
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );

      final blocks = reader.read(path: file.path);
      expect(blocks.single, isA<AcpMappedInlineImageContentBlock>());
      final attachment = (blocks.single as AcpMappedInlineImageContentBlock).attachment;
      expect(attachment.mime, "image/png");
      expect(attachment.filename, file.uri.pathSegments.last);
      expect(attachment.base64, isNotEmpty);
    });

    test("returns metadata when the source exceeds the transcript image limit", () async {
      final file = tempFile("cursor-generated-image-large");
      file.writeAsBytesSync(Uint8List(maxTranscriptImageBytes + 1));

      final blocks = reader.read(path: file.path);
      expect(blocks.single, isA<AcpMappedMetadataImageContentBlock>());
      expect(
        (blocks.single as AcpMappedMetadataImageContentBlock).reason,
        AcpImageDegradationReason.oversized,
      );
    });

    test("returns no blocks when the source path is missing", () {
      expect(
        reader.read(path: "${Directory.systemTemp.path}/does-not-exist-${DateTime.now().microsecondsSinceEpoch}.png"),
        isEmpty,
      );
    });

    test("returns metadata when the source has no image signature, even with an image extension", () {
      final file = tempFile("cursor-generated-image-garbage");
      file.writeAsBytesSync(Uint8List.fromList(const [0x00, 0x01, 0x02, 0x03]));

      final blocks = reader.read(path: file.path);
      expect(blocks.single, isA<AcpMappedMetadataImageContentBlock>());
      expect(
        (blocks.single as AcpMappedMetadataImageContentBlock).reason,
        AcpImageDegradationReason.invalid,
      );
    });

    test("returns metadata when the source file is empty, same as unsigned bytes", () {
      // An existing-but-empty file degrades exactly like garbage content: a
      // metadata chip, not a silent drop.
      final file = tempFile("cursor-generated-image-empty");
      file.writeAsBytesSync(Uint8List(0));

      final blocks = reader.read(path: file.path);
      expect(blocks.single, isA<AcpMappedMetadataImageContentBlock>());
      final block = blocks.single as AcpMappedMetadataImageContentBlock;
      expect(block.reason, AcpImageDegradationReason.invalid);
      expect(block.attachment.mime, "image/png", reason: "mime falls back to the extension hint");
    });

    test("accepts a signed image at the decoded transcript limit", () {
      final file = tempFile("cursor-generated-image-limit");
      final bytes = Uint8List(maxTranscriptImageBytes);
      bytes.setRange(0, 8, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      file.writeAsBytesSync(bytes);

      final blocks = reader.read(path: file.path);
      expect(blocks.single, isA<AcpMappedInlineImageContentBlock>());
    });
  });
}

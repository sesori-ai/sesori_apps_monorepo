import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:cursor_plugin/src/repositories/mappers/cursor_generate_image_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxInlineMessageAttachmentBytes;
import "package:test/test.dart";

void main() {
  group("CursorGenerateImageMapper", () {
    const mapper = CursorGenerateImageMapper(contentMapper: AcpContentMapper());

    test("maps a bounded local PNG into an inline image block", () async {
      final file = File("${Directory.systemTemp.path}/output.png");
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(
        Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
      );

      final blocks = mapper.mapPath(path: file.path);
      expect(blocks.single, isA<AcpMappedInlineImageContentBlock>());
      final attachment = (blocks.single as AcpMappedInlineImageContentBlock).attachment;
      expect(attachment.mime, "image/png");
      expect(attachment.filename, "output.png");
      expect(attachment.base64, isNotEmpty);
    });

    test("returns metadata when the source exceeds the inline transport limit", () async {
      final file = File("${Directory.systemTemp.path}/cursor-generate-image-large-${DateTime.now().microsecondsSinceEpoch}.png");
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      file.writeAsBytesSync(Uint8List(maxInlineMessageAttachmentBytes + 1));

      final blocks = mapper.mapPath(path: file.path);
      expect(blocks.single, isA<AcpMappedMetadataImageContentBlock>());
      expect(
        (blocks.single as AcpMappedMetadataImageContentBlock).reason,
        AcpImageDegradationReason.oversized,
      );
    });

    test("returns no blocks when the source path is missing", () {
      expect(mapper.mapPath(path: "/tmp/does-not-exist-${DateTime.now().microsecondsSinceEpoch}.png"), isEmpty);
    });
  });
}

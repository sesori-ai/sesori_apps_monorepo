import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  test("a staged file always goes out as octet-stream under its own name", () {
    final ComposerAttachment file = ComposerFileAttachment(
      source: ComposerAttachmentSource.picker,
      bytes: Uint8List(1),
      filename: "notes.pdf",
    );

    expect(file.mime, composerFileAttachmentMime);
    expect(file.filename, "notes.pdf");
  });

  test("a staged image keeps its sniffed type and may have no name", () {
    final ComposerAttachment image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List(1), filename: null);

    expect(image.mime, "image/png");
    expect(image.filename, isNull);
  });
}

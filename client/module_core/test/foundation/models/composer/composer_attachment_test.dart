import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  test("a staged file always goes out as octet-stream under its own name", () {
    final file = ComposerFileAttachment(
      source: ComposerAttachmentSource.picker,
      bytes: Uint8List(3),
      filename: "notes.pdf",
    );

    expect(file.mime, composerFileAttachmentMime);
    expect(file.filename, "notes.pdf");
    expect(file.inlineByteCount, 3);
  });

  test("a staged image keeps its sniffed type and may have no name", () {
    final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List(2), filename: null);

    expect(image.mime, "image/png");
    expect(image.filename, isNull);
    expect(image.inlineByteCount, 2);
  });

  test("a file the bridge holds adds no bytes to the request", () {
    const file = ComposerHostFileAttachment(path: "/uploads/ses_1/2026-11-01-abc/notes.txt", filename: "notes.txt");

    expect(file.inlineByteCount, 0);
    expect(file.filename, "notes.txt");
  });
}

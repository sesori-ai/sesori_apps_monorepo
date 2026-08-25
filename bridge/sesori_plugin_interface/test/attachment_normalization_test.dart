import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("normalizes base64 and rejects invalid input", () {
    expect(normalizeAttachmentBase64(encoded: "YQ"), "YQ==");
    expect(normalizeAttachmentBase64(encoded: "not base64"), isNull);
  });

  test("normalizes bounded MIME values and extracts essence", () {
    expect(
      normalizeAttachmentMime(raw: " IMAGE/PNG; Charset=X ", fallback: "fallback", maxCharacters: 255),
      "image/png; charset=x",
    );
    expect(normalizeAttachmentMime(raw: " ", fallback: "fallback", maxCharacters: 255), "fallback");
    expect(normalizeAttachmentMime(raw: "ABCD", fallback: "fallback", maxCharacters: 3), "abc");
    expect(attachmentMimeEssence(mime: "image/png; charset=x"), "image/png");
  });
}

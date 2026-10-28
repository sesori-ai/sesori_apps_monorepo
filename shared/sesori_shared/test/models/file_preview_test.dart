import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("FilePreviewResponse", () {
    test("tags each outcome with its wire type", () {
      expect(const FilePreviewResponse.tooLarge().toJson(), {"type": "too_large"});
      expect(const FilePreviewResponse.text(content: "a").toJson(), {"type": "text", "content": "a"});
    });

    test("reads an image preview", () {
      expect(
        FilePreviewResponse.fromJson({"type": "image", "mime": "image/png", "base64": "AA==", "byteLength": 1}),
        const FilePreviewResponse.image(mime: "image/png", base64: "AA==", byteLength: 1),
      );
    });
  });
}

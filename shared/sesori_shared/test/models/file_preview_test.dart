import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("FilePreviewResponse", () {
    test("tags each outcome with its wire type", () {
      expect(const FilePreviewResponse.tooLarge().toJson(), {"type": "too_large"});
      expect(const FilePreviewResponse.text(content: "a").toJson(), {"type": "text", "content": "a"});
      expect(const FilePreviewResponse.pdf(base64: "AA==").toJson(), {"type": "pdf", "base64": "AA=="});
    });

    test("reads an image preview", () {
      expect(
        FilePreviewResponse.fromJson({"type": "image", "mime": "image/png", "base64": "AA==", "byteLength": 1}),
        const FilePreviewResponse.image(mime: "image/png", base64: "AA==", byteLength: 1),
      );
    });
  });

  group("FilePreviewRequest", () {
    test("reads a request without acceptsPdf, from an older app, as not accepting PDFs", () {
      expect(FilePreviewRequest.fromJson({"path": "/a.pdf"}), const FilePreviewRequest(path: "/a.pdf"));
      expect(const FilePreviewRequest(path: "/a.pdf").acceptsPdf, isFalse);
    });
  });
}

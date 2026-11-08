import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/desktop_file_clipboard.dart";

void main() {
  DesktopFileClipboard clipboardWith({required List<String> files, required String? text}) =>
      DesktopFileClipboard.forTesting(readFiles: () async => files, readText: () async => text);

  test("hands over copied files with their names as the clipboard's text", () async {
    final clipboard = clipboardWith(files: ["/work/report.pdf", "/work/shot.png"], text: "report.pdf\rshot.png");

    expect(await clipboard.readPaths(), ["/work/report.pdf", "/work/shot.png"]);
  });

  test("hands over copied files when the clipboard has no text", () async {
    final clipboard = clipboardWith(files: ["/work/report.pdf"], text: null);

    expect(await clipboard.readPaths(), ["/work/report.pdf"]);
  });

  test("hands over copied files whose text is a file URL", () async {
    final clipboard = clipboardWith(files: ["/work/report.pdf"], text: "file:///work/report.pdf");

    expect(await clipboard.readPaths(), ["/work/report.pdf"]);
  });

  test("reads a copied web link as no files, though macOS reports it as a path", () async {
    final clipboard = clipboardWith(files: ["/"], text: " https://example.com/\n");

    expect(await clipboard.readPaths(), isEmpty);
  });

  test("reads an empty pasteboard as no files", () async {
    final clipboard = clipboardWith(files: const [], text: "plain words");

    expect(await clipboard.readPaths(), isEmpty);
  });
}

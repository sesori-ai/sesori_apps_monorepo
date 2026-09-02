import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/desktop_image_clipboard.dart";
import "package:sesori_desktop/core/platform/desktop_pasteboard_client.dart";

class _FakePasteboardClient() implements DesktopPasteboardClient {
  Uint8List? bytes;
  Uint8List? imageToRead;

  @override
  Future<Uint8List?> readImage() async => imageToRead;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {
    this.bytes = bytes;
  }
}

void main() {
  test("reads the original bytes through the injected Pasteboard client", () async {
    final bytes = Uint8List.fromList(const [1, 2, 3]);
    final client = _FakePasteboardClient()..imageToRead = bytes;
    final clipboard = DesktopImageClipboard(pasteboardClient: client);

    final result = await clipboard.readImage();

    expect(identical(result, bytes), isTrue);
  });

  test("writes the original bytes through the injected Pasteboard client", () async {
    final bytes = Uint8List.fromList(const [1, 2, 3]);
    final client = _FakePasteboardClient();
    final clipboard = DesktopImageClipboard(pasteboardClient: client);

    await clipboard.writeImage(bytes: bytes);

    expect(identical(client.bytes, bytes), isTrue);
  });
}

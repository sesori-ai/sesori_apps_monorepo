import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/desktop_file_image_saver.dart";
import "package:sesori_mobile/core/platform/file_save_client.dart";

class _FakeFileSaveClient implements FileSaveClient {
  bool result = false;
  Uint8List? bytes;
  String? mime;
  String? filename;

  @override
  Future<bool> saveFile({
    required Uint8List bytes,
    required String mime,
    required String filename,
  }) async {
    this.bytes = bytes;
    this.mime = mime;
    this.filename = filename;
    return result;
  }
}

void main() {
  test("saves the original image bytes and metadata through the file client", () async {
    final bytes = Uint8List.fromList(const [1, 2, 3]);
    final client = _FakeFileSaveClient()..result = true;
    final saver = DesktopFileImageSaver(fileSaveClient: client);

    expect(saver.isSupported, isTrue);

    final result = await saver.saveImage(bytes: bytes, mime: "image/png", filename: "image.png");

    expect(result, ImageSaveResult.saved);
    expect(identical(client.bytes, bytes), isTrue);
    expect(client.mime, "image/png");
    expect(client.filename, "image.png");
  });

  test("reports a cancelled save dialog without writing a file", () async {
    final saver = DesktopFileImageSaver(fileSaveClient: _FakeFileSaveClient());

    final result = await saver.saveImage(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      mime: "image/png",
      filename: "image.png",
    );

    expect(result, ImageSaveResult.cancelled);
  });
}

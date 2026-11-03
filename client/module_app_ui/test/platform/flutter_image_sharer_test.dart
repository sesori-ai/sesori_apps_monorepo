import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/platform/flutter_image_sharer.dart";
import "package:sesori_app_ui/src/platform/share_plus_client.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:share_plus/share_plus.dart";

class _FakeSharePlusClient() implements SharePlusClient {
  ShareParams? params;

  @override
  Future<void> share({required ShareParams params}) async {
    this.params = params;
  }
}

void main() {
  test("shares the original bytes and origin through the injected SharePlus client", () async {
    final bytes = Uint8List.fromList(const [1, 2, 3]);
    final client = _FakeSharePlusClient();
    final sharer = FlutterImageSharer(sharePlusClient: client);

    await sharer.shareImage(
      bytes: bytes,
      mime: "image/png",
      filename: "image.png",
      origin: const ImageShareOrigin(left: 1, top: 2, width: 3, height: 4),
    );

    final params = client.params ?? fail("SharePlus received no share request");
    final file = params.files?.single ?? fail("The share request carried no file");
    expect(await file.readAsBytes(), bytes);
    expect(file.mimeType, "image/png");
    expect(params.fileNameOverrides, ["image.png"]);
    expect(params.sharePositionOrigin, const Rect.fromLTWH(1, 2, 3, 4));
  });
}

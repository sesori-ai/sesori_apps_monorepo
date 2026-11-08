import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  test("encodes platform-decoded RGBA as a JPEG with transparency on white", () async {
    // Two pixels: opaque red, then fully transparent; offset in a larger
    // buffer the way a ByteData view can be.
    final buffer = Uint8List.fromList(const [9, 9, 255, 0, 0, 255, 0, 0, 0, 0]);
    final rgba = Uint8List.sublistView(buffer, 2);

    final jpeg = await const ComposerJpegBuilder().encodeRgba(rgba: rgba, width: 2, height: 1);

    final decoded = image.decodeJpg(jpeg) ?? fail("not a JPEG");
    expect([decoded.width, decoded.height], [2, 1]);
    expect(decoded.getPixel(0, 0).r, greaterThan(200));
    final transparent = decoded.getPixel(1, 0);
    expect([transparent.g, transparent.b], everyElement(greaterThan(150)));
  });
}

import "dart:math" as math;
import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  const builder = ComposerImageDownscaleBuilder();

  /// Random pixels barely compress, so these encodings stay above the
  /// 1 MiB threshold at modest dimensions.
  image.Image noise({required int width, required int height, int numChannels = 3, int? alpha}) {
    final random = math.Random(42);
    final canvas = image.Image(width: width, height: height, numChannels: numChannels);
    for (final pixel in canvas) {
      pixel
        ..r = random.nextInt(256)
        ..g = random.nextInt(256)
        ..b = random.nextInt(256);
      if (alpha != null) pixel.a = alpha;
    }
    return canvas;
  }

  Uint8List downscaledBytes(ComposerImageDownscaleResult result) => switch (result) {
    ComposerImageDownscaled(:final bytes) => bytes,
    ComposerImageKept() => fail("the image was kept"),
    ComposerImageDownscaleFailed(:final cause) => fail("downscaling failed: $cause"),
  };

  group("ComposerImageDownscaleBuilder", () {
    test("shrinks an oversized PNG to a JPEG whose long side is 2048 px", () async {
      final png = image.encodePng(noise(width: 1200, height: 3000), level: 1);
      expect(png.length, greaterThan(1024 * 1024));

      final jpeg = downscaledBytes(await builder.downscale(bytes: png, format: SupportedRasterImageFormat.png));

      expect(detectSupportedRasterImageFormat(bytes: jpeg), SupportedRasterImageFormat.jpeg);
      final decoded = image.decodeJpg(jpeg) ?? fail("not a JPEG");
      expect(decoded.height, 2048);
      expect(decoded.width, (1200 * 2048 / 3000).round());
    });

    test("composites transparency onto white", () async {
      final png = image.encodePng(noise(width: 2200, height: 600, numChannels: 4, alpha: 0), level: 1);
      expect(png.length, greaterThan(1024 * 1024));

      final jpeg = downscaledBytes(await builder.downscale(bytes: png, format: SupportedRasterImageFormat.png));

      final decoded = image.decodeJpg(jpeg) ?? fail("not a JPEG");
      final pixel = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
      expect([pixel.r, pixel.g, pixel.b], everyElement(greaterThan(250)));
    });

    test("applies the EXIF orientation before re-encoding", () async {
      final source = noise(width: 2400, height: 1000);
      source.exif.imageIfd.orientation = 6;
      final jpeg = image.encodeJpg(source, quality: 100);
      expect(jpeg.length, greaterThan(1024 * 1024));

      final result = downscaledBytes(await builder.downscale(bytes: jpeg, format: SupportedRasterImageFormat.jpeg));

      final decoded = image.decodeJpg(result) ?? fail("not a JPEG");
      expect(decoded.height, greaterThan(decoded.width));
    });

    test("shrinks an extreme panorama to at least a pixel high", () async {
      final png = image.encodePng(noise(width: 120000, height: 4), level: 1);
      expect(png.length, greaterThan(1024 * 1024));

      final jpeg = downscaledBytes(await builder.downscale(bytes: png, format: SupportedRasterImageFormat.png));

      final decoded = image.decodeJpg(jpeg) ?? fail("not a JPEG");
      expect(decoded.width, 2048);
      expect(decoded.height, 1);
    });

    test("keeps a small image untouched", () async {
      final png = image.encodePng(noise(width: 64, height: 64));

      expect(
        await builder.downscale(bytes: png, format: SupportedRasterImageFormat.png),
        isA<ComposerImageKept>(),
      );
    });

    test("keeps an oversized GIF so its animation survives", () async {
      final gif = Uint8List(2 * 1024 * 1024)..setAll(0, "GIF89a".codeUnits);

      expect(
        await builder.downscale(bytes: gif, format: SupportedRasterImageFormat.gif),
        isA<ComposerImageKept>(),
      );
    });

    test("reports undecodable bytes as a failure", () async {
      final bytes = Uint8List(2 * 1024 * 1024)..setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      expect(
        await builder.downscale(bytes: bytes, format: SupportedRasterImageFormat.png),
        isA<ComposerImageDownscaleFailed>(),
      );
    });
  });
}

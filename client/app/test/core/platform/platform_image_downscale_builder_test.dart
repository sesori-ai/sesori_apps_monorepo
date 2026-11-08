import "dart:ui" as ui;

import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/platform_image_downscale_builder.dart";

Future<Uint8List> _png({required int width, required int height}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) fail("could not encode the test image");
  return data.buffer.asUint8List();
}

Future<(int, int)> _size({required Uint8List bytes}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final size = (image.width, image.height);
  image.dispose();
  codec.dispose();
  return size;
}

void main() {
  final downscaleBuilder = PlatformImageDownscaleBuilder(jpegBuilder: const ComposerJpegBuilder());

  testWidgets("a photo larger than the size rule comes back as a JPEG within it", (tester) async {
    await tester.runAsync(() async {
      final png = await _png(width: 3000, height: 1200);

      final result = await downscaleBuilder.downscale(bytes: png);

      if (result is! PlatformImageDownscaled) fail("not downscaled: $result");
      expect(detectSupportedRasterImageFormat(bytes: result.jpeg), SupportedRasterImageFormat.jpeg);
      expect(await _size(bytes: result.jpeg), (2048, 819));
    });
  });

  testWidgets("a photo core reads at an allowed size is kept", (tester) async {
    await tester.runAsync(() async {
      final png = await _png(width: 400, height: 300);

      expect(await downscaleBuilder.downscale(bytes: png), isA<PlatformImageKept>());
    });
  });

  testWidgets("bytes the platform can't decode are kept for core to turn away", (tester) async {
    await tester.runAsync(() async {
      final garbage = Uint8List.fromList(List<int>.generate(32, (i) => i));

      expect(await downscaleBuilder.downscale(bytes: garbage), isA<PlatformImageKept>());
    });
  });

  test("a GIF is kept without decoding so it stays animated", () async {
    final gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 1, 0, 1, 0, 0, 0]);

    expect(await downscaleBuilder.downscale(bytes: gif), isA<PlatformImageKept>());
  });
}

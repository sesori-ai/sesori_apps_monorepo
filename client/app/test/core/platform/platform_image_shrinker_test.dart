import "dart:ui" as ui;

import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/platform_image_shrinker.dart";

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
  final shrinker = PlatformImageShrinker(encoder: const ComposerImageDownscaleBuilder());

  testWidgets("a photo larger than the size rule comes back as a JPEG within it", (tester) async {
    await tester.runAsync(() async {
      final png = await _png(width: 3000, height: 1200);

      final shrunk = await shrinker.shrink(bytes: png) ?? fail("not decoded");

      expect(detectSupportedRasterImageFormat(bytes: shrunk), SupportedRasterImageFormat.jpeg);
      expect(await _size(bytes: shrunk), (2048, 819));
    });
  });

  testWidgets("a photo core reads at an allowed size comes back untouched", (tester) async {
    await tester.runAsync(() async {
      final png = await _png(width: 400, height: 300);

      expect(await shrinker.shrink(bytes: png), same(png));
    });
  });

  testWidgets("bytes the platform can't decode give null", (tester) async {
    await tester.runAsync(() async {
      expect(await shrinker.shrink(bytes: Uint8List.fromList(List<int>.generate(32, (i) => i))), isNull);
    });
  });
}

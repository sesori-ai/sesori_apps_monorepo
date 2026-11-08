import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Shrinks a picked photo with the platform's own image decoder.
///
/// That decoder reads formats shared core can't, such as HEIF on Android 9 and
/// later, and it downsamples while decoding, so a large photo is never decoded
/// at full size.
@lazySingleton
class PlatformImageShrinker({required final ComposerImageDownscaleBuilder _encoder}) {
  /// Returns the image as a JPEG whose long side is at most
  /// [ComposerImageDownscaleBuilder.maxLongSide], or [bytes] untouched when
  /// shared core already reads them and they are no larger than that. Returns
  /// null when the platform can't decode them.
  Future<Uint8List?> shrink({required Uint8List bytes}) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      final loaded = buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final described = descriptor = await ui.ImageDescriptor.encoded(loaded);
      const maxLongSide = ComposerImageDownscaleBuilder.maxLongSide;
      final longSide = math.max(described.width, described.height);
      if (longSide <= maxLongSide && detectSupportedRasterImageFormat(bytes: bytes) != null) return bytes;

      final scale = math.min(1.0, maxLongSide / longSide);
      final decoder = codec = await described.instantiateCodec(
        targetWidth: math.max(1, (described.width * scale).round()),
        targetHeight: math.max(1, (described.height * scale).round()),
      );
      final frame = (await decoder.getNextFrame()).image;
      try {
        final pixels = await frame.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        if (pixels == null) return null;
        return await _encoder.encodeRgbaAsJpeg(
          rgba: pixels.buffer.asUint8List(pixels.offsetInBytes, pixels.lengthInBytes),
          width: frame.width,
          height: frame.height,
        );
      } finally {
        frame.dispose();
      }
    } on Object catch (error, stackTrace) {
      logw("The platform could not decode a picked image", error, stackTrace);
      return null;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

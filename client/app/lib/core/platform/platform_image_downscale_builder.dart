import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

sealed class const PlatformImageDownscaleResult();

/// The photo was re-encoded as a JPEG within the size rule.
final class const PlatformImageDownscaled({required final Uint8List jpeg}) extends PlatformImageDownscaleResult;

/// The original bytes should be handed over as they are: a GIF, which keeps
/// its animation; a photo shared core reads that is already within the size
/// rule; or one the platform can't decode, which shared core then turns away.
final class const PlatformImageKept() extends PlatformImageDownscaleResult;

/// Downscales a picked photo with the platform's own image decoder.
///
/// That decoder reads formats shared core can't, such as HEIF on Android 9 and
/// later, and it downsamples while decoding, so a large photo is never decoded
/// at full size.
@lazySingleton
class PlatformImageDownscaleBuilder({required final ComposerJpegBuilder _jpegBuilder}) {
  Future<PlatformImageDownscaleResult> downscale({required Uint8List bytes}) async {
    final format = detectSupportedRasterImageFormat(bytes: bytes);
    if (format == SupportedRasterImageFormat.gif) return const PlatformImageKept();

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      final loaded = buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final described = descriptor = await ui.ImageDescriptor.encoded(loaded);
      const maxLongSide = ComposerImageDownscaleBuilder.maxLongSide;
      final longSide = math.max(described.width, described.height);
      if (longSide <= maxLongSide && format != null) return const PlatformImageKept();

      final scale = math.min(1.0, maxLongSide / longSide);
      final decoder = codec = await described.instantiateCodec(
        targetWidth: math.max(1, (described.width * scale).round()),
        targetHeight: math.max(1, (described.height * scale).round()),
      );
      final frame = (await decoder.getNextFrame()).image;
      try {
        final pixels = await frame.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
        if (pixels == null) return const PlatformImageKept();
        final jpeg = await _jpegBuilder.encodeRgba(
          rgba: pixels.buffer.asUint8List(pixels.offsetInBytes, pixels.lengthInBytes),
          width: frame.width,
          height: frame.height,
        );
        return PlatformImageDownscaled(jpeg: jpeg);
      } finally {
        frame.dispose();
      }
    } on Object catch (error, stackTrace) {
      logw("The platform could not decode a picked image", error, stackTrace);
      return const PlatformImageKept();
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

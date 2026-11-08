import "dart:isolate";
import "dart:math" as math;
import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:injectable/injectable.dart";

import "../foundation/image/composer_jpeg_builder.dart";
import "../foundation/models/image/supported_raster_image_format.dart";

sealed class const ComposerImageDownscaleResult();

/// The image was re-encoded as a JPEG that is smaller than the original.
final class const ComposerImageDownscaled({required final Uint8List bytes}) extends ComposerImageDownscaleResult;

/// The original bytes should be staged as they are: the image is already
/// small, animated, too large to decode safely, or re-encoding did not shrink
/// it.
final class const ComposerImageKept() extends ComposerImageDownscaleResult;

/// Decoding or re-encoding failed. Callers stage the original bytes.
final class const ComposerImageDownscaleFailed({
  required final Object cause,
  required final StackTrace stackTrace,
}) extends ComposerImageDownscaleResult;

/// Shrinks oversized composer images so a prompt stays well inside the inline
/// image budgets coding backends accept.
///
/// An image above [_thresholdBytes] that is not a GIF (GIFs keep their
/// animation) is resized so its long side is at most [maxLongSide] pixels,
/// never upscaled, and re-encoded as a JPEG. Transparency is composited onto
/// white because JPEG has no alpha channel. The work runs off the calling
/// isolate.
@lazySingleton
class const ComposerImageDownscaleBuilder() {
  static const _thresholdBytes = 1024 * 1024;

  /// The longest side, in pixels, of an image this builder re-encodes.
  static const maxLongSide = 2048;
  static const _maxDecodedPixels = 24 * 1000 * 1000;

  Future<ComposerImageDownscaleResult> downscale({
    required Uint8List bytes,
    required SupportedRasterImageFormat format,
  }) async {
    if (bytes.length <= _thresholdBytes || format == SupportedRasterImageFormat.gif) {
      return const ComposerImageKept();
    }
    try {
      return await Isolate.run(() => _downscale(bytes: bytes, format: format));
    } on Object catch (cause, stackTrace) {
      // The isolate itself can fail, for example when it runs out of memory.
      return ComposerImageDownscaleFailed(cause: cause, stackTrace: stackTrace);
    }
  }

  static ComposerImageDownscaleResult _downscale({
    required Uint8List bytes,
    required SupportedRasterImageFormat format,
  }) {
    try {
      final decoder = _decoderFor(format: format);
      final info = decoder.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) {
        throw const FormatException("The image header could not be read");
      }
      // Decoding allocates every pixel, so a huge canvas is kept as it is
      // rather than risking the memory.
      if (info.width * info.height > _maxDecodedPixels) return const ComposerImageKept();
      final frame = decoder.decodeFrame(0);
      if (frame == null) throw const FormatException("The image has no decodable frame");

      // JPEG re-encoding drops the EXIF orientation, so apply it to the pixels.
      final oriented = image.bakeOrientation(frame);
      final scale = maxLongSide / math.max(oriented.width, oriented.height);
      final resized = scale >= 1
          ? oriented
          : image.copyResize(
              oriented,
              // At least a pixel each way, so an extreme panorama still shrinks.
              width: math.max(1, (oriented.width * scale).round()),
              height: math.max(1, (oriented.height * scale).round()),
              interpolation: image.Interpolation.average,
            );
      final encoded = ComposerJpegBuilder.encode(source: resized);
      return encoded.length < bytes.length ? ComposerImageDownscaled(bytes: encoded) : const ComposerImageKept();
    } on Object catch (cause, stackTrace) {
      return ComposerImageDownscaleFailed(cause: cause, stackTrace: stackTrace);
    }
  }

  static image.Decoder _decoderFor({required SupportedRasterImageFormat format}) => switch (format) {
    SupportedRasterImageFormat.bmp => image.BmpDecoder(),
    // Never reached: GIFs are kept before decoding so they stay animated.
    SupportedRasterImageFormat.gif => image.GifDecoder(),
    SupportedRasterImageFormat.jpeg => image.JpegDecoder(),
    SupportedRasterImageFormat.png => image.PngDecoder(),
    SupportedRasterImageFormat.webp => image.WebPDecoder(),
  };
}

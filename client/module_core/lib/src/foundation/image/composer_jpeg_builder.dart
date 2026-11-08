import "dart:isolate";
import "dart:typed_data";

import "package:image/image.dart" as image;
import "package:injectable/injectable.dart";

/// Encodes composer images as JPEG, the one format every downscaled image is
/// staged in. Transparency is composited onto white because JPEG has no alpha
/// channel.
@lazySingleton
class const ComposerJpegBuilder() {
  /// The JPEG quality every downscaled composer image is encoded at.
  static const jpegQuality = 85;

  /// Encodes [source] on the calling isolate.
  static Uint8List encode({required image.Image source}) =>
      image.encodeJpg(_onWhite(source: source), quality: jpegQuality);

  /// Encodes straight (not premultiplied) RGBA pixels that a platform decoder
  /// produced, off the calling isolate.
  Future<Uint8List> encodeRgba({required Uint8List rgba, required int width, required int height}) {
    return Isolate.run(
      () => encode(
        source: image.Image.fromBytes(
          width: width,
          height: height,
          bytes: rgba.buffer,
          bytesOffset: rgba.offsetInBytes,
          numChannels: 4,
          order: image.ChannelOrder.rgba,
        ),
      ),
    );
  }

  static image.Image _onWhite({required image.Image source}) {
    if (!source.hasAlpha) return source;
    final background = image.Image(width: source.width, height: source.height);
    image.fill(background, color: image.ColorRgb8(255, 255, 255));
    return image.compositeImage(background, source.convert(format: image.Format.uint8, numChannels: 4));
  }
}

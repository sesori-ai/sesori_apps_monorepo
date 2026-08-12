import "dart:async";
import "dart:isolate";
import "dart:typed_data";

import "package:image/image.dart" as image;

import "../../api/attachment_spill_storage.dart";

sealed class const AttachmentThumbnailBuildResult();

final class const AttachmentThumbnailRendered({
  required final Uint8List bytes,
  required final AttachmentThumbnailFormat format,
}) extends AttachmentThumbnailBuildResult;

final class const AttachmentThumbnailUnsupported() extends AttachmentThumbnailBuildResult;

final class const AttachmentThumbnailTooLarge() extends AttachmentThumbnailBuildResult;

final class const AttachmentThumbnailFailed({required final Object cause, required final StackTrace stackTrace})
    extends AttachmentThumbnailBuildResult;

class const AttachmentThumbnailBuilder() {
  static const _size = 512;
  static const _jpegQuality = 82;
  static const _maxDecodedPixels = 24 * 1024 * 1024;

  String? detectSupportedMime({required Uint8List bytes}) {
    try {
      final decoder = _decoderForSupportedData(bytes: bytes);
      return decoder == null || !decoder.isValidFile(bytes) ? null : _mimeForFormat(decoder.format);
    } on image.ImageException {
      return null;
    } on FormatException {
      return null;
    }
  }

  String? _mimeForFormat(image.ImageFormat? format) => switch (format) {
    image.ImageFormat.bmp => "image/bmp",
    image.ImageFormat.gif => "image/gif",
    image.ImageFormat.jpg => "image/jpeg",
    image.ImageFormat.png => "image/png",
    image.ImageFormat.webp => "image/webp",
    _ => null,
  };

  Future<AttachmentThumbnailBuildResult> build({required Uint8List bytes}) {
    return Isolate.run(() => _build(bytes: bytes));
  }

  AttachmentThumbnailBuildResult _build({required Uint8List bytes}) {
    try {
      final decoder = _decoderForSupportedData(bytes: bytes);
      if (decoder == null || !decoder.isValidFile(bytes)) {
        return const AttachmentThumbnailUnsupported();
      }
      final info = decoder.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) {
        return const AttachmentThumbnailUnsupported();
      }
      if (info.width * info.height > _maxDecodedPixels) {
        return const AttachmentThumbnailTooLarge();
      }
      final firstFrame = decoder.decodeFrame(0);
      if (firstFrame == null) return const AttachmentThumbnailUnsupported();

      final oriented = image.bakeOrientation(firstFrame);
      final thumbnail = image.copyResizeCropSquare(
        oriented,
        size: _size,
        interpolation: image.Interpolation.average,
      );
      final transparent = thumbnail.hasAlpha && thumbnail.any((pixel) => pixel.a != pixel.maxChannelValue);
      return transparent
          ? AttachmentThumbnailRendered(
              bytes: image.encodePng(thumbnail),
              format: AttachmentThumbnailFormat.png,
            )
          : AttachmentThumbnailRendered(
              bytes: image.encodeJpg(thumbnail, quality: _jpegQuality),
              format: AttachmentThumbnailFormat.jpeg,
            );
    } on image.ImageException {
      return const AttachmentThumbnailUnsupported();
    } on FormatException {
      return const AttachmentThumbnailUnsupported();
    } on Object catch (cause, stackTrace) {
      return AttachmentThumbnailFailed(cause: cause, stackTrace: stackTrace);
    }
  }

  image.Decoder? _decoderForSupportedData({required Uint8List bytes}) {
    if (_startsWith(bytes: bytes, signature: const [0xff, 0xd8, 0xff])) {
      return image.JpegDecoder();
    }
    if (_startsWith(bytes: bytes, signature: const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
      return image.PngDecoder();
    }
    if (_startsWith(bytes: bytes, signature: const [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
        _startsWith(bytes: bytes, signature: const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
      return image.GifDecoder();
    }
    if (bytes.length >= 12 &&
        _startsWith(bytes: bytes, signature: const [0x52, 0x49, 0x46, 0x46]) &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return image.WebPDecoder();
    }
    if (_startsWith(bytes: bytes, signature: const [0x42, 0x4d])) {
      return image.BmpDecoder();
    }
    return null;
  }

  bool _startsWith({required Uint8List bytes, required List<int> signature}) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }
}

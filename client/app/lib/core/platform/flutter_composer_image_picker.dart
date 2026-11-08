import "package:flutter/foundation.dart";
import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";

import "platform_image_shrinker.dart";

/// Mobile gallery picker for composer images.
///
/// Shared core owns the staged-image size rule ([ComposerImageDownscaleBuilder])
/// and validates the returned bytes.
///
/// iOS applies the same limits natively first. It scales a GIF frame by frame,
/// so the GIF keeps its animation, and it turns HEIC into JPEG. Android would
/// re-encode any resized pick, flattening an animated GIF, so Android picks the
/// original: a GIF is handed over untouched, and anything else is shrunk with
/// the platform decoder, which also reads HEIF and very large photos.
@LazySingleton(as: ComposerFilePicker)
class FlutterComposerImagePicker({
  required final ImagePicker picker,
  required final PlatformImageShrinker shrinker,
}) implements ComposerFilePicker {
  static final double _maxDimension = ComposerImageDownscaleBuilder.maxLongSide.toDouble();

  final ImagePicker _picker = picker;
  final PlatformImageShrinker _shrinker = shrinker;

  @override
  Future<ComposerPickResult?> pick() async {
    final nativeResize = defaultTargetPlatform == TargetPlatform.iOS;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: nativeResize ? _maxDimension : null,
      maxHeight: nativeResize ? _maxDimension : null,
      imageQuality: nativeResize ? ComposerImageDownscaleBuilder.jpegQuality : null,
      requestFullMetadata: false,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (nativeResize || detectSupportedRasterImageFormat(bytes: bytes) == SupportedRasterImageFormat.gif) {
      return ComposerPickedImage(bytes: bytes, filename: file.name);
    }
    final shrunk = await _shrinker.shrink(bytes: bytes);
    if (shrunk == null) throw const UnsupportedAttachmentImageError();
    final format = detectSupportedRasterImageFormat(bytes: shrunk);
    return ComposerPickedImage(
      bytes: shrunk,
      // A HEIF photo comes back as a JPEG, so its name follows.
      filename: format == null ? file.name : path.setExtension(file.name, format.filenameExtension),
    );
  }
}

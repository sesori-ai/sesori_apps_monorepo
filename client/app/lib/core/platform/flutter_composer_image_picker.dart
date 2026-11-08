import "package:flutter/foundation.dart";
import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Mobile gallery picker for composer images.
///
/// Shared core owns the staged-image size rule ([ComposerImageDownscaleBuilder])
/// and validates the returned bytes.
///
/// iOS applies the same limits natively first. It scales a GIF frame by frame,
/// so the GIF keeps its animation, and it turns HEIC into JPEG. It also keeps a
/// 24 MP photo from reaching core larger than core will decode. Android
/// re-encodes any resized pick, which flattens an animated GIF, so Android hands
/// over the original: core downscales it unless it is a GIF, which stays at its
/// original size.
@LazySingleton(as: ComposerFilePicker)
class FlutterComposerImagePicker({required final ImagePicker picker}) implements ComposerFilePicker {
  static final double _maxDimension = ComposerImageDownscaleBuilder.maxLongSide.toDouble();

  final ImagePicker _picker = picker;

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

    return ComposerPickedImage(
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
  }
}

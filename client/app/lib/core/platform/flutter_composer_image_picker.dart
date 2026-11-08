import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Mobile gallery picker for composer images.
///
/// Shared core owns the staged-image size rule ([ComposerImageDownscaleBuilder])
/// and validates the returned bytes. The plugin's native pass applies the same
/// limits up front, which keeps a full-resolution photo out of memory and turns
/// formats such as HEIC into a JPEG core can stage, so its picks arrive already
/// within the rule.
@LazySingleton(as: ComposerFilePicker)
class FlutterComposerImagePicker({required final ImagePicker picker}) implements ComposerFilePicker {
  static final double _maxDimension = ComposerImageDownscaleBuilder.maxLongSide.toDouble();

  final ImagePicker _picker = picker;

  @override
  Future<ComposerPickResult?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: ComposerImageDownscaleBuilder.jpegQuality,
      requestFullMetadata: false,
    );
    if (file == null) return null;

    return ComposerPickedImage(
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
  }
}

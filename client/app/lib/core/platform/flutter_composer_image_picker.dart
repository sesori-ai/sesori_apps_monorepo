import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Mobile gallery picker for composer images.
///
/// The plugin performs the platform re-encoding/downscale pass; shared core
/// validates the returned bytes and creates the transport attachment.
@LazySingleton(as: ComposerImagePicker)
class FlutterComposerImagePicker({required final ImagePicker picker}) implements ComposerImagePicker {
  static const double _maxDimension = 2048;
  static const int _jpegQuality = 85;

  final ImagePicker _picker = picker;

  @override
  Future<ComposerPickedImage?> pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _jpegQuality,
      requestFullMetadata: false,
    );
    if (file == null) return null;

    return ComposerPickedImage(
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
  }
}

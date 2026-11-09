import "package:flutter/foundation.dart";
import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";

import "document_picker_client.dart";
import "platform_image_downscale_builder.dart";

/// Mobile picker for the composer: a photo from the gallery, or any files
/// through the system's document picker ([DocumentPickerClient]).
///
/// Shared core owns the staged-image size rule ([ComposerImageDownscaleBuilder])
/// and validates the returned bytes.
///
/// iOS applies the same limits natively first. It scales a GIF frame by frame,
/// so the GIF keeps its animation, and it turns HEIC into JPEG. Android would
/// re-encode any resized pick, flattening an animated GIF, so Android picks the
/// original and [PlatformImageDownscaleBuilder] shrinks anything but a GIF with
/// the platform decoder, which also reads HEIF and very large photos.
@LazySingleton(as: ComposerFilePicker)
class FlutterComposerFilePicker({
  required final ImagePicker picker,
  required final PlatformImageDownscaleBuilder downscaleBuilder,
  required final DocumentPickerClient documentPicker,
}) implements ComposerFilePicker {
  static final double _maxDimension = ComposerImageDownscaleBuilder.maxLongSide.toDouble();

  /// The name image_picker gives its own copy: `image_picker_<id>` on iOS,
  /// which never passes on the library's file name, and `image_picker` on
  /// Android when the photo has no display name.
  static final _pickerCopyName = RegExp(r"^image_picker(_[0-9A-Fa-f-]+)?$");

  final ImagePicker _picker = picker;
  final PlatformImageDownscaleBuilder _downscaleBuilder = downscaleBuilder;
  final DocumentPickerClient _documentPicker = documentPicker;

  @override
  Future<ComposerPickResult?> pick({required ComposerPickSource source}) => switch (source) {
    ComposerPickSource.photos => _pickPhoto(),
    ComposerPickSource.files => _documentPicker.pick(),
  };

  Future<ComposerPickResult?> _pickPhoto() async {
    final nativeResize = defaultTargetPlatform == TargetPlatform.iOS;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: nativeResize ? _maxDimension : null,
      maxHeight: nativeResize ? _maxDimension : null,
      imageQuality: nativeResize ? ComposerJpegBuilder.jpegQuality : null,
      requestFullMetadata: false,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final filename = _photoFilename(pickedName: file.name);
    if (nativeResize) return ComposerPickedImage(bytes: bytes, filename: filename);
    return switch (await _downscaleBuilder.downscale(bytes: bytes)) {
      PlatformImageDownscaled(:final jpeg) => ComposerPickedImage(
        bytes: jpeg,
        filename: path.setExtension(filename, SupportedRasterImageFormat.jpeg.filenameExtension),
      ),
      PlatformImageKept() => ComposerPickedImage(bytes: bytes, filename: filename),
    };
  }

  /// The photo's own name, or `photo.<ext>` in place of a name image_picker
  /// made up for its copy, which would otherwise label the tile and name the
  /// file a bridge saves.
  static String _photoFilename({required String pickedName}) {
    if (!_pickerCopyName.hasMatch(path.basenameWithoutExtension(pickedName))) return pickedName;
    return "photo${path.extension(pickedName)}";
  }
}

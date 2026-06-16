import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:mime/mime.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Maximum edge length (px) for a picked image. Larger images are downscaled
/// by `image_picker`, which also re-encodes them to JPEG — this keeps the
/// base64 payload sent over the relay small and normalises formats like HEIC.
const _maxImageEdge = 2048.0;

/// JPEG quality used when `image_picker` re-encodes a downscaled image.
const _imageQuality = 85;

@LazySingleton(as: MediaPicker)
class FlutterMediaPicker implements MediaPicker {
  final ImagePicker _picker;

  FlutterMediaPicker({required ImagePicker picker}) : _picker = picker;

  @override
  Future<PickedMedia?> pickImageFromGallery() => _pick(ImageSource.gallery);

  @override
  Future<PickedMedia?> pickImageFromCamera() => _pick(ImageSource.camera);

  Future<PickedMedia?> _pick(ImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: _maxImageEdge,
        maxHeight: _maxImageEdge,
        imageQuality: _imageQuality,
      );
    } on PlatformException catch (error) {
      throw MediaPickerException("Failed to pick image: ${error.message ?? error.code}");
    }

    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? lookupMimeType(file.name, headerBytes: bytes) ?? "image/jpeg";

    return PickedMedia(bytes: bytes, mimeType: mimeType, filename: file.name);
  }
}

import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Method channel bridging to the native clipboard. The native side downscales
/// and re-encodes the image (mirroring the gallery/camera picker) before
/// returning it, so the base64 payload sent over the relay stays small.
const _channel = MethodChannel("sesori/clipboard");

/// Reads an image from the system clipboard via a platform [MethodChannel].
///
/// The native handler returns `null` when the clipboard holds no image, or a map
/// of `{bytes, mimeType, filename}` otherwise. Platforms without the channel
/// (e.g. unit tests, web) surface a [MissingPluginException], which is treated
/// as an empty clipboard.
@LazySingleton(as: ClipboardImageReader)
class FlutterClipboardImageReader implements ClipboardImageReader {
  const FlutterClipboardImageReader();

  @override
  Future<PickedMedia?> readImage() async {
    final Map<Object?, Object?>? result;
    try {
      result = await _channel.invokeMapMethod<Object?, Object?>("readImage");
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw MediaPickerException("Failed to read clipboard image: ${error.message ?? error.code}");
    }

    if (result == null) return null;

    final bytes = result["bytes"];
    if (bytes is! Uint8List || bytes.isEmpty) return null;

    final mimeType = result["mimeType"];
    final filename = result["filename"];

    return PickedMedia(
      bytes: bytes,
      mimeType: mimeType is String ? mimeType : "image/jpeg",
      filename: filename is String ? filename : null,
    );
  }
}

import "media_picker.dart";

/// Platform-agnostic reader for an image held on the system clipboard.
///
/// Used to attach an image when the user pastes (Cmd/Ctrl+V, the selection
/// toolbar's "Paste", or the in-composer "Paste" action) instead of picking one
/// from the gallery or camera. Returns the clipboard image as [PickedMedia] so
/// it flows through the exact same attachment path, or `null` when the clipboard
/// holds no image. Implementations throw [MediaPickerException] on failure.
abstract class ClipboardImageReader {
  /// Returns the image currently on the clipboard, or `null` when there is none.
  Future<PickedMedia?> readImage();
}

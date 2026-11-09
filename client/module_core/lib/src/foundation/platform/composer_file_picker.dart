import "dart:typed_data";

/// Product-shell seam for choosing what to attach to a composer.
///
/// Implementations own the platform picker. Validation, MIME sniffing,
/// transport limits and the routing of host paths remain in the composer
/// attachment dispatcher.
abstract interface class ComposerFilePicker() {
  /// Opens the picker for [source]. Returns `null` when the user dismisses
  /// it.
  Future<ComposerPickResult?> pick({required ComposerPickSource source});
}

/// Where the user picks from.
enum ComposerPickSource() {
  /// The photo library.
  photos,

  /// Any files, from the platform's file browser.
  files,
}

sealed class const ComposerPickResult();

/// Raw bytes of one image, from a picker that hands over content rather than
/// a path on this computer.
final class const ComposerPickedImage({
  required final Uint8List bytes,
  required final String? filename,
}) extends ComposerPickResult;

/// Absolute paths of files or folders on this computer.
final class const ComposerPickedHostPaths({
  required final List<String> paths,

  /// Picked files the picker left out, never copied or read, because each was
  /// over the per-message attachment budget on its own.
  required final int oversizedCount,
}) extends ComposerPickResult;

import "dart:typed_data";

sealed class const FilePreviewState();

final class const FilePreviewLoading() extends FilePreviewState;

/// A UTF-8 text file.
final class const FilePreviewShowsText({required final String content}) extends FilePreviewState;

/// An image, decoded from the bridge's base64.
final class const FilePreviewShowsImage({
  required final Uint8List bytes,
  required final String mime,
}) extends FilePreviewState;

/// Nothing to show, for [reason].
final class const FilePreviewUnavailable({required final FilePreviewUnavailableReason reason}) extends FilePreviewState;

enum FilePreviewUnavailableReason() {
  missing,
  tooLarge,

  /// A directory, a binary file, or text that is not UTF-8.
  unsupported,
  denied,

  /// The connected bridge cannot serve previews until it is updated.
  bridgeTooOld,
  failed,
}

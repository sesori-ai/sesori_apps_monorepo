import "dart:typed_data";

/// The outcome of asking the bridge for a file preview.
sealed class const FilePreviewResult();

/// A UTF-8 text file.
final class const FilePreviewTextContent({required final String content}) extends FilePreviewResult;

/// An image, decoded from the bridge's base64.
final class const FilePreviewImageContent({
  required final Uint8List bytes,
  required final String mime,
}) extends FilePreviewResult;

/// The bridge answered but has nothing to show, for [reason].
final class const FilePreviewContentUnavailable({required final FilePreviewUnavailableReason reason})
    extends FilePreviewResult;

/// The bridge predates `POST /filesystem/file`.
final class const FilePreviewBridgeTooOld() extends FilePreviewResult;

/// The request failed in transport or on the bridge, or its image did not decode.
final class const FilePreviewFailed({
  // ignore: no_slop_linter/prefer_specific_type, transport errors and decode failures share this path
  required final Object innerError,
  required final StackTrace? stackTrace,
}) extends FilePreviewResult;

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

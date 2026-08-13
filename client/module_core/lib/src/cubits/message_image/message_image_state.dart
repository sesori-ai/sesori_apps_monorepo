import "dart:typed_data";

final class const MessageImageState({
  required final MessageImagePreviewState preview,
  required final MessageImageOriginalState original,
});

sealed class const MessageImagePreviewState();

final class const MessageImagePreviewLoading() extends MessageImagePreviewState;

final class const MessageImagePreviewLoaded({
  required final Uint8List bytes,
  required final String mime,
  required final String actionFilename,
  required final Uri? originalUri,
}) extends MessageImagePreviewState;

final class const MessageImagePreviewUnsupported() extends MessageImagePreviewState;

final class const MessageImagePreviewRejected() extends MessageImagePreviewState;

final class const MessageImagePreviewFailed({
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  required final Object cause,
  required final StackTrace stackTrace,
}) extends MessageImagePreviewState;

sealed class const MessageImageOriginalState();

final class const MessageImageOriginalAvailable() extends MessageImageOriginalState;

final class const MessageImageOriginalUnavailable() extends MessageImageOriginalState;

final class const MessageImageOriginalLoading() extends MessageImageOriginalState;

final class const MessageImageOriginalLoaded({
  required final Uint8List bytes,
  required final String mime,
  required final String actionFilename,
}) extends MessageImageOriginalState;

final class const MessageImageOriginalRejected() extends MessageImageOriginalState;

final class const MessageImageOriginalFailed({
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  required final Object cause,
  required final StackTrace stackTrace,
}) extends MessageImageOriginalState;

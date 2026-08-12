import "dart:typed_data";

sealed class const MessageImageState();

final class const MessageImageLoading() extends MessageImageState;

final class const MessageImageLoaded({
  required final Uint8List bytes,
  required final String mime,
  required final String actionFilename,
  required final Uri? originalUri,
}) extends MessageImageState;

final class const MessageImageUnsupported() extends MessageImageState;

final class const MessageImageRejected() extends MessageImageState;

final class const MessageImageFailed({
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  required final Object cause,
  required final StackTrace stackTrace,
}) extends MessageImageState;

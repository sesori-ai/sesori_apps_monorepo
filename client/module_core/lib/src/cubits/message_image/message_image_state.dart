import "dart:typed_data";

sealed class const MessageImageState();

final class const MessageImageLoading() extends MessageImageState;

final class const MessageImageLoaded({
    required this.bytes,
    required this.mime,
    required this.actionFilename,
    required this.originalUri,
  }) extends MessageImageState {
  final Uint8List bytes;
  final String mime;
  final String actionFilename;
  final Uri? originalUri;
}

final class const MessageImageUnsupported() extends MessageImageState;

final class const MessageImageRejected() extends MessageImageState;

final class const MessageImageFailed({
    required this.cause,
    required this.stackTrace,
  }) extends MessageImageState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;
}

import "dart:typed_data";

sealed class MessageImageState {
  const MessageImageState();
}

final class MessageImageLoading extends MessageImageState {
  const MessageImageLoading();
}

final class MessageImageLoaded extends MessageImageState {
  final Uint8List bytes;
  final String mime;
  final String actionFilename;
  final Uri? originalUri;

  const MessageImageLoaded({
    required this.bytes,
    required this.mime,
    required this.actionFilename,
    required this.originalUri,
  });
}

final class MessageImageUnsupported extends MessageImageState {
  const MessageImageUnsupported();
}

final class MessageImageRejected extends MessageImageState {
  const MessageImageRejected();
}

final class MessageImageFailed extends MessageImageState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;

  const MessageImageFailed({
    required this.cause,
    required this.stackTrace,
  });
}

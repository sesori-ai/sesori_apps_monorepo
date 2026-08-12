import "dart:typed_data";

final class MessageImageState {
  final MessageImagePreviewState preview;
  final MessageImageOriginalState original;

  const MessageImageState({required this.preview, required this.original});
}

sealed class MessageImagePreviewState {
  const MessageImagePreviewState();
}

final class MessageImagePreviewLoading extends MessageImagePreviewState {
  const MessageImagePreviewLoading();
}

final class MessageImagePreviewLoaded extends MessageImagePreviewState {
  final Uint8List bytes;
  final String mime;
  final String actionFilename;
  final Uri? originalUri;

  const MessageImagePreviewLoaded({
    required this.bytes,
    required this.mime,
    required this.actionFilename,
    required this.originalUri,
  });
}

final class MessageImagePreviewUnsupported extends MessageImagePreviewState {
  const MessageImagePreviewUnsupported();
}

final class MessageImagePreviewRejected extends MessageImagePreviewState {
  const MessageImagePreviewRejected();
}

final class MessageImagePreviewFailed extends MessageImagePreviewState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;

  const MessageImagePreviewFailed({required this.cause, required this.stackTrace});
}

sealed class MessageImageOriginalState {
  const MessageImageOriginalState();
}

final class MessageImageOriginalAvailable extends MessageImageOriginalState {
  const MessageImageOriginalAvailable();
}

final class MessageImageOriginalUnavailable extends MessageImageOriginalState {
  const MessageImageOriginalUnavailable();
}

final class MessageImageOriginalLoading extends MessageImageOriginalState {
  const MessageImageOriginalLoading();
}

final class MessageImageOriginalLoaded extends MessageImageOriginalState {
  final Uint8List bytes;
  final String mime;
  final String actionFilename;

  const MessageImageOriginalLoaded({
    required this.bytes,
    required this.mime,
    required this.actionFilename,
  });
}

final class MessageImageOriginalRejected extends MessageImageOriginalState {
  const MessageImageOriginalRejected();
}

final class MessageImageOriginalFailed extends MessageImageOriginalState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;

  const MessageImageOriginalFailed({required this.cause, required this.stackTrace});
}

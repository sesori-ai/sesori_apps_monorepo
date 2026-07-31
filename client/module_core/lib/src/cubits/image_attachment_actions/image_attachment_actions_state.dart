enum ImageAttachmentAction { copy, share, save }

sealed class ImageAttachmentActionsState {
  const ImageAttachmentActionsState();
}

final class ImageAttachmentActionsIdle extends ImageAttachmentActionsState {
  const ImageAttachmentActionsIdle();
}

final class ImageAttachmentActionRunning extends ImageAttachmentActionsState {
  final ImageAttachmentAction action;

  const ImageAttachmentActionRunning({required this.action});
}

final class ImageAttachmentSaved extends ImageAttachmentActionsState {
  const ImageAttachmentSaved();
}

final class ImageAttachmentCopied extends ImageAttachmentActionsState {
  const ImageAttachmentCopied();
}

final class ImageAttachmentSaveAccessDenied extends ImageAttachmentActionsState {
  const ImageAttachmentSaveAccessDenied();
}

final class ImageAttachmentShareFailed extends ImageAttachmentActionsState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;

  const ImageAttachmentShareFailed({
    required this.cause,
    required this.stackTrace,
  });
}

final class ImageAttachmentCopyFailed extends ImageAttachmentActionsState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;

  const ImageAttachmentCopyFailed({
    required this.cause,
    required this.stackTrace,
  });
}

final class ImageAttachmentSaveFailed extends ImageAttachmentActionsState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;

  const ImageAttachmentSaveFailed({
    required this.cause,
    required this.stackTrace,
  });
}

enum ImageAttachmentAction() { copy, share, save }

sealed class const ImageAttachmentActionsState();

final class const ImageAttachmentActionsIdle() extends ImageAttachmentActionsState;

final class const ImageAttachmentActionRunning({required this.action}) extends ImageAttachmentActionsState {
  final ImageAttachmentAction action;
}

final class const ImageAttachmentSaved() extends ImageAttachmentActionsState;

final class const ImageAttachmentCopied() extends ImageAttachmentActionsState;

final class const ImageAttachmentSaveAccessDenied() extends ImageAttachmentActionsState;

final class const ImageAttachmentShareFailed({
    required this.cause,
    required this.stackTrace,
  }) extends ImageAttachmentActionsState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;
}

final class const ImageAttachmentCopyFailed({
    required this.cause,
    required this.stackTrace,
  }) extends ImageAttachmentActionsState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;
}

final class const ImageAttachmentSaveFailed({
    required this.cause,
    required this.stackTrace,
  }) extends ImageAttachmentActionsState {
  // ignore: no_slop_linter/prefer_specific_type, caught Dart failures can be Error or Exception
  final Object cause;
  final StackTrace stackTrace;
}

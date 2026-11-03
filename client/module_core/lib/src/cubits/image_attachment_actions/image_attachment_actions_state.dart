enum ImageAttachmentAction() {
  copy,
  share,
  save,
}

sealed class const ImageAttachmentActionsState();

final class const ImageAttachmentActionsIdle() extends ImageAttachmentActionsState;

final class const ImageAttachmentActionRunning({required final ImageAttachmentAction action})
    extends ImageAttachmentActionsState;

final class const ImageAttachmentSaved() extends ImageAttachmentActionsState;

final class const ImageAttachmentCopied() extends ImageAttachmentActionsState;

final class const ImageAttachmentSaveAccessDenied() extends ImageAttachmentActionsState;

final class const ImageAttachmentShareFailed({
  required final Object cause,
  required final StackTrace stackTrace,
}) extends ImageAttachmentActionsState;

final class const ImageAttachmentCopyFailed({
  required final Object cause,
  required final StackTrace stackTrace,
}) extends ImageAttachmentActionsState;

final class const ImageAttachmentSaveFailed({
  required final Object cause,
  required final StackTrace stackTrace,
}) extends ImageAttachmentActionsState;

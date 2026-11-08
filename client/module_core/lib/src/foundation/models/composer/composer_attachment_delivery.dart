import "composer_attachment.dart";

/// Whether every staged attachment can reach the agent: an image needs a
/// harness that takes inline images, and a file a bridge that saves uploads.
/// An unresolved (null) capability can't deliver either.
bool canDeliverComposerAttachments({
  required List<ComposerAttachment> attachments,
  required bool? inlineImages,
  required bool? fileUploads,
}) => attachments.every(
  (attachment) => switch (attachment.kind) {
    ComposerAttachmentKind.image => inlineImages ?? false,
    ComposerAttachmentKind.file => fileUploads ?? false,
  },
);

/// Whether a staged [attachment] can no longer reach the agent and should be
/// cleared: only a known `false` strands it. Null is a capability still
/// resolving, such as during a dropped connection, and keeps what is staged.
bool isComposerAttachmentStranded({
  required ComposerAttachment attachment,
  required bool? inlineImages,
  required bool? fileUploads,
}) => switch (attachment.kind) {
  ComposerAttachmentKind.image => inlineImages == false,
  ComposerAttachmentKind.file => fileUploads == false,
};

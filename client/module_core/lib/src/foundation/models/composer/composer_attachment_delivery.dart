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

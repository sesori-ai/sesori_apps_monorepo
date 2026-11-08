import "../../foundation/models/composer/composer_attachment.dart";

/// What one pick or drop adds to a composer. A single drop can stage images,
/// insert paths and turn away the rest at the same time, so the three parts
/// travel together.
final class const ComposerAttachOutcome({
  /// Images to stage, in the order they were chosen.
  required final List<ComposerAttachment> attachments,

  /// Paths on this computer to insert into the prompt text at the caret,
  /// already separated and quoted.
  required final String? insertedText,

  /// The files that could not be added, if any.
  required final ComposerAttachRejection? rejection,
});

/// Why chosen files could not be added. When several apply, the outcome
/// reports the first in declaration order.
enum ComposerAttachRejectionReason() {
  /// Not an image, so it cannot reach a bridge on another computer yet.
  notTransferable,

  /// An image the backend does not accept as an attachment.
  attachmentsUnsupported,

  /// An image too large for what is left of the prompt's attachment budget.
  overBudget,
}

final class const ComposerAttachRejection({
  required final ComposerAttachRejectionReason reason,

  /// Every file that was not added, whatever its own reason.
  required final int count,
});

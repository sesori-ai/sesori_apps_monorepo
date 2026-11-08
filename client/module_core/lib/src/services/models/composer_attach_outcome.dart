import "../../foundation/models/composer/composer_attachment.dart";

/// What one pick, drop or paste adds to a composer. A single drop can stage
/// attachments, insert paths and turn away the rest at the same time, so the
/// three parts travel together.
final class const ComposerAttachOutcome({
  /// Images and files to stage, in the order they were chosen.
  required final List<ComposerAttachment> attachments,

  /// Paths on this computer to insert into the prompt text at the caret,
  /// already separated and quoted.
  required final String? insertedText,

  /// How many files were not added for each reason; empty when every file
  /// was added.
  required final Map<ComposerAttachRejectionReason, int> rejections,
});

/// Why a chosen file could not be added.
enum ComposerAttachRejectionReason() {
  /// Not an image, and the bridge on another computer can't take other files
  /// (it predates file uploads), or the file couldn't be read.
  notTransferable,

  /// A folder, which can't be sent to a bridge on another computer.
  folderNotTransferable,

  /// An image the backend does not accept, on a bridge that can't take it as
  /// a file either.
  attachmentsUnsupported,

  /// Too large for what is left of the prompt's attachment budget.
  overBudget,
}

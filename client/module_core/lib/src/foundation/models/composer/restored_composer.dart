import "package:meta/meta.dart";

import "composer_attachment.dart";
import "composer_draft.dart";

/// A sent user message brought back into a composer, to edit it or send it
/// again elsewhere.
@immutable
final class const RestoredComposer({
  /// The message's text without the bridge's saved-file notes; empty when the
  /// message held only attachments.
  required final ComposerDraft draft,

  /// Its images, fetched again, and the files the bridge saved for it, in that
  /// order.
  required final List<ComposerAttachment> attachments,

  /// How many of its attachments the bridge can no longer serve, such as a
  /// saved file past the upload sweep or an image a harness pruned. They are
  /// left out, and the composer says how many.
  required final int leftOutCount,
});

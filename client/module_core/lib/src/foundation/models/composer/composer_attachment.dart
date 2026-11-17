import "dart:typed_data";

import "package:meta/meta.dart";

/// Maximum decoded attachment bytes staged for one outbound prompt.
///
/// This is decimal 50 MB rather than 50 MiB so ordinary request envelopes fit
/// below the relay's 64 MiB message limit. RelayClient also preflights the
/// actual serialized request for prompts with unusually large text or metadata.
const maxComposerPromptAttachmentBytes = 50 * 1000 * 1000;

/// The type a staged file goes out with: it tells the bridge to save the file
/// and name its path to the agent, rather than pass it on inline.
const composerFileAttachmentMime = "application/octet-stream";

/// An image or file staged in the composer. How it reaches the agent depends
/// on its variant: an image or file goes inline (base64 `file_data` prompt
/// part) with the submission it accompanies, and a file the bridge already
/// holds goes by its path.
///
/// Held in memory only: staged attachments are not part of the persisted
/// composer draft. They live as long as the composer that staged them; the
/// ones it hands on wait in `ComposerDraftRepository` until the next composer
/// takes them, or until sign-out drops them.
///
/// The bytes a variant carries are owned by that attachment. They are not
/// defensively copied — the buffers are megabytes and come straight from the
/// picker — so callers must treat them as read-only.
@immutable
sealed class const ComposerAttachment() {
  /// The original name, when it has one.
  String? get filename;

  /// How many bytes the attachment adds to the request it goes out with.
  int get inlineByteCount;
}

/// A supported image, sent inline to a harness that takes images.
final class const ComposerImageAttachment({
  /// The sniffed image type.
  required final String mime,
  required final Uint8List bytes,

  /// The original name; an image picked or pasted without one has none.
  @override required final String? filename,
}) extends ComposerAttachment {
  @override
  int get inlineByteCount => bytes.length;
}

/// How the user added a staged file to the composer.
enum ComposerAttachmentSource() {
  /// The attach button's photo or file picker.
  picker,

  /// Dropped on the composer.
  drop,

  /// Pasted: copied files, or an image from the clipboard.
  paste,
}

/// Any other file, or an image the harness can't take. The bridge saves it and
/// gives the agent its path, so it always goes out as
/// [composerFileAttachmentMime] under its original name.
final class const ComposerFileAttachment({
  required final Uint8List bytes,
  @override required final String filename,

  /// How it was added, for analytics only; it never reaches the bridge.
  required final ComposerAttachmentSource source,
}) extends ComposerAttachment {
  String get mime => composerFileAttachmentMime;

  @override
  int get inlineByteCount => bytes.length;
}

/// A file the bridge already holds, such as one it saved for an earlier
/// prompt, brought back into the composer. It goes out by [path] rather than
/// its bytes, so nothing is uploaded again, and the agent gets the same note
/// naming the path as when the file was first sent.
///
/// [path] is on the bridge's computer, not this device's, so it is never
/// opened here.
final class const ComposerHostFileAttachment({
  required final String path,
  @override required final String filename,
}) extends ComposerAttachment {
  @override
  int get inlineByteCount => 0;
}

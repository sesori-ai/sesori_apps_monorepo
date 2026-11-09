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

/// An image or file staged in the composer, transmitted inline (base64
/// `file_data` prompt part) with the submission it accompanies. How it
/// reaches the agent depends on its variant.
///
/// Held in memory only: staged attachments are not part of the persisted
/// composer draft, so they live exactly as long as the composer that staged
/// them.
///
/// [bytes] is owned by this attachment. It is not defensively copied — the
/// buffers are megabytes and come straight from the picker — so callers must
/// treat it as read-only.
@immutable
sealed class const ComposerAttachment() {
  /// The type the attachment goes out with.
  String get mime;

  Uint8List get bytes;

  /// The original name, when it has one.
  String? get filename;
}

/// A supported image, sent inline to a harness that takes images.
final class const ComposerImageAttachment({
  /// The sniffed image type.
  @override required final String mime,
  @override required final Uint8List bytes,

  /// The original name; an image picked or pasted without one has none.
  @override required final String? filename,
}) extends ComposerAttachment;

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
  @override required final Uint8List bytes,
  @override required final String filename,

  /// How it was added, for analytics only; it never reaches the bridge.
  required final ComposerAttachmentSource source,
}) extends ComposerAttachment {
  @override
  String get mime => composerFileAttachmentMime;
}

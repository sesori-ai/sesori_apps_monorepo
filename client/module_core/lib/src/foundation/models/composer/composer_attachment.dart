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

/// How a staged attachment reaches the agent.
enum ComposerAttachmentKind() {
  /// A supported image, sent inline to a harness that takes images.
  image,

  /// Any other file, or an image the harness can't take. The bridge saves it
  /// and gives the agent its path.
  file,
}

/// An image or file staged in the composer, transmitted inline (base64
/// `file_data` prompt part) with the submission it accompanies.
///
/// Held in memory only: staged attachments are not part of the persisted
/// composer draft, so they live exactly as long as the composer that staged
/// them.
///
/// [bytes] is owned by this attachment. It is not defensively copied — the
/// buffers are megabytes and come straight from the picker — so callers must
/// treat it as read-only.
@immutable
final class const ComposerAttachment({
  required final ComposerAttachmentKind kind,

  /// The sniffed image type for an image, and [composerFileAttachmentMime]
  /// for a file.
  required final String mime,
  required final Uint8List bytes,

  /// The original name; an image picked or pasted without one has none, and a
  /// file always has one.
  required final String? filename,
});

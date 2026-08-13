import "dart:typed_data";

import "package:meta/meta.dart";

/// Maximum decoded attachment bytes staged for one outbound prompt.
///
/// This is decimal 50 MB rather than 50 MiB so ordinary request envelopes fit
/// below the relay's 64 MiB message limit. RelayClient also preflights the
/// actual serialized request for prompts with unusually large text or metadata.
const maxComposerPromptAttachmentBytes = 50 * 1000 * 1000;

/// An image staged in the composer, transmitted inline (base64 `file_data`
/// prompt part) with the submission it accompanies.
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
  required final String mime,
  required final Uint8List bytes,
  required final String? filename,
});

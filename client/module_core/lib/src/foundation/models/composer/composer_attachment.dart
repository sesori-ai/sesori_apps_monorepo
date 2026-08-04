import "dart:typed_data";

import "package:meta/meta.dart";

/// Maximum decoded attachment bytes staged for one outbound prompt.
///
/// This is decimal 50 MB rather than 50 MiB: base64 expansion plus the relay
/// request envelope must remain below the relay's 64 MiB message limit.
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
final class ComposerAttachment {
  final String mime;
  final Uint8List bytes;
  final String? filename;

  const ComposerAttachment({
    required this.mime,
    required this.bytes,
    required this.filename,
  });
}

import "dart:typed_data";

import "package:meta/meta.dart";

/// An image staged in the composer, transmitted inline (base64 `file_data`
/// prompt part) with the submission it accompanies.
///
/// Held in memory only: staged attachments are not part of the persisted
/// composer draft, so they live exactly as long as the composer that staged
/// them.
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

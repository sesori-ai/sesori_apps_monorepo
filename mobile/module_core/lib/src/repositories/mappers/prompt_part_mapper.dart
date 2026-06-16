import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../../platform/media_picker.dart";

/// Maps a user-selected [PickedMedia] to the shared [PromptPart] wire type.
///
/// Inline image bytes are base64-encoded into a [PromptPart.fileData] part,
/// which the bridge forwards to the assistant as a `data:` URL.
extension PickedMediaToPromptPart on PickedMedia {
  PromptPart toPromptPart() => PromptPart.fileData(
    mime: mimeType,
    base64: base64Encode(bytes),
    filename: filename,
  );
}

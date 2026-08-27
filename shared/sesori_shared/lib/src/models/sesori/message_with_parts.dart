import "package:freezed_annotation/freezed_annotation.dart";

import "message.dart";
import "message_part.dart";
import "session.dart";

part "message_with_parts.freezed.dart";

part "message_with_parts.g.dart";

/// Response body for `POST /session/messages`.
@Freezed(fromJson: true, toJson: true)
sealed class MessageWithPartsResponse with _$MessageWithPartsResponse {
  const factory({
    required List<MessageWithParts> messages,

    /// Cursor for the next older page, to be sent back verbatim as the
    /// request's `before`. Null means the transcript is complete.
    // COMPATIBILITY 2026-08-08 (v1.8.0): Bridges that predate pagination omit nextCursor, which decodes to null and correctly means "complete". Make this required once those bridges are unsupported.
    required int? nextCursor,

    // COMPATIBILITY 2026-08-27 (v1.8.2): Older bridges omit replayedPromptDefaults, which decodes to null and means no replay-derived selection is available. Remove this comment when bridges without this field are unsupported.
    required SessionPromptDefaults? replayedPromptDefaults,
  }) = _MessageWithPartsResponse;

  factory fromJson(Map<String, dynamic> json) => _$MessageWithPartsResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class MessageWithParts with _$MessageWithParts {
  const factory({
    required Message info,
    required List<MessagePart> parts,
  }) = _MessageWithParts;

  factory fromJson(Map<String, dynamic> json) => _$MessageWithPartsFromJson(json);
}

import "package:freezed_annotation/freezed_annotation.dart";

import "message.dart";
import "message_part.dart";

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

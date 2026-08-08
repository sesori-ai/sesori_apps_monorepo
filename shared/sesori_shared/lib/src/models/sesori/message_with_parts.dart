import "package:freezed_annotation/freezed_annotation.dart";

import "message.dart";
import "message_part.dart";

part "message_with_parts.freezed.dart";

part "message_with_parts.g.dart";

/// Response body for `POST /session/messages`.
@Freezed(fromJson: true, toJson: true)
sealed class MessageWithPartsResponse with _$MessageWithPartsResponse {
  const factory MessageWithPartsResponse({
    required List<MessageWithParts> messages,

    /// Cursor for the next older page, to be sent back verbatim as the
    /// request's `before`. Null means the transcript is complete — either
    /// because everything was returned, or because the bridge predates
    /// pagination and always returns everything.
    required int? nextCursor,
  }) = _MessageWithPartsResponse;

  factory MessageWithPartsResponse.fromJson(Map<String, dynamic> json) => _$MessageWithPartsResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class MessageWithParts with _$MessageWithParts {
  const factory MessageWithParts({
    required Message info,
    required List<MessagePart> parts,
  }) = _MessageWithParts;

  factory MessageWithParts.fromJson(Map<String, dynamic> json) => _$MessageWithPartsFromJson(json);
}

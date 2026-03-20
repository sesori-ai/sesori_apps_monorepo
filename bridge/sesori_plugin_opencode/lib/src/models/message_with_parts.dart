import "package:freezed_annotation/freezed_annotation.dart";

import "message.dart";
import "message_part.dart";

part "message_with_parts.freezed.dart";

part "message_with_parts.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class MessageWithParts with _$MessageWithParts {
  const factory MessageWithParts({
    required Message info,
    required List<MessagePart> parts,
  }) = _MessageWithParts;

  factory MessageWithParts.fromJson(Map<String, dynamic> json) => _$MessageWithPartsFromJson(json);
}

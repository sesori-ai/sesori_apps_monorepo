// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'assistant_message.g.dart';
import 'user_message.g.dart';

@immutable
abstract interface class Message {
  const Message();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory Message.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["role"];
    switch (discriminator) {
      case "user":
        return UserMessage.fromJson(map);
      case "assistant":
        return AssistantMessage.fromJson(map);
      default:
        return MessageUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [Message] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class MessageUnknown implements Message {
  const MessageUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

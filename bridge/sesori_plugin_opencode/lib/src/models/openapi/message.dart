// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.905745Z

import 'assistant_message.dart';
import 'user_message.dart';

abstract interface class Message {
  const Message();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `dynamic` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `dynamic`.
  dynamic toJson();

  factory Message.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["role"];
    switch (discriminator) {
      case "user":
        return UserMessage.fromJson(map);
      case "assistant":
        return AssistantMessage.fromJson(map);
      default:
        throw FormatException('Unknown Message value: $discriminator');
    }
  }
}

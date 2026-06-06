// GENERATED FILE - DO NOT EDIT BY HAND

import 'assistant_message.dart';
import 'user_message.dart';

abstract interface class Message {
  const Message();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

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

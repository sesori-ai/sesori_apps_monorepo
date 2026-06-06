// GENERATED FILE - DO NOT EDIT BY HAND

import 'assistant_message.dart';
import 'user_message.dart';

abstract interface class Message {
  const Message();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory Message.fromJson(Map<String, dynamic> json) {
    final discriminator = json["role"];
    switch (discriminator) {
      case "user":
        return UserMessage.fromJson(json);
      case "assistant":
        return AssistantMessage.fromJson(json);
      default:
        throw FormatException('Unknown Message value: $discriminator');
    }
  }
}

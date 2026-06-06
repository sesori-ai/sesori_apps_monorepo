// GENERATED FILE - DO NOT EDIT BY HAND

import 'session_message_agent_switched.dart';
import 'session_message_assistant.dart';
import 'session_message_compaction.dart';
import 'session_message_model_switched.dart';
import 'session_message_shell.dart';
import 'session_message_synthetic.dart';
import 'session_message_system.dart';
import 'session_message_user.dart';

abstract interface class SessionMessage {
  const SessionMessage();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory SessionMessage.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "agent-switched":
        return SessionMessageAgentSwitched.fromJson(map);
      case "model-switched":
        return SessionMessageModelSwitched.fromJson(map);
      case "user":
        return SessionMessageUser.fromJson(map);
      case "synthetic":
        return SessionMessageSynthetic.fromJson(map);
      case "system":
        return SessionMessageSystem.fromJson(map);
      case "shell":
        return SessionMessageShell.fromJson(map);
      case "assistant":
        return SessionMessageAssistant.fromJson(map);
      case "compaction":
        return SessionMessageCompaction.fromJson(map);
      default:
        throw FormatException('Unknown SessionMessage value: $discriminator');
    }
  }
}

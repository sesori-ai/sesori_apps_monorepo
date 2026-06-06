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

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      case "agent-switched":
        return SessionMessageAgentSwitched.fromJson(json);
      case "model-switched":
        return SessionMessageModelSwitched.fromJson(json);
      case "user":
        return SessionMessageUser.fromJson(json);
      case "synthetic":
        return SessionMessageSynthetic.fromJson(json);
      case "system":
        return SessionMessageSystem.fromJson(json);
      case "shell":
        return SessionMessageShell.fromJson(json);
      case "assistant":
        return SessionMessageAssistant.fromJson(json);
      case "compaction":
        return SessionMessageCompaction.fromJson(json);
      default:
        throw FormatException('Unknown SessionMessage value: $discriminator');
    }
  }
}

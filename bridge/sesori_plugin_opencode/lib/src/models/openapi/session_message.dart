// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_agent_switched.dart';
import 'session_message_assistant.dart';
import 'session_message_compaction.dart';
import 'session_message_model_switched.dart';
import 'session_message_shell.dart';
import 'session_message_synthetic.dart';
import 'session_message_system.dart';
import 'session_message_user.dart';

@immutable
abstract interface class SessionMessage {
  const SessionMessage();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory SessionMessage.fromJson(Object json) {
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
        return SessionMessageUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [SessionMessage] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class SessionMessageUnknown implements SessionMessage {
  const SessionMessageUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

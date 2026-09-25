// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_agent_selected.g.dart';
import 'session_message_assistant.g.dart';
import 'session_message_compaction.g.dart';
import 'session_message_idle.g.dart';
import 'session_message_location_switched.g.dart';
import 'session_message_model_selected.g.dart';
import 'session_message_shell.g.dart';
import 'session_message_skill.g.dart';
import 'session_message_synthetic.g.dart';
import 'session_message_system.g.dart';
import 'session_message_user.g.dart';

@immutable
abstract interface class SessionMessageInfo {
  const SessionMessageInfo();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory SessionMessageInfo.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "agent-switched":
        return SessionMessageAgentSelected.fromJson(map);
      case "model-switched":
        return SessionMessageModelSelected.fromJson(map);
      case "location-switched":
        return SessionMessageLocationSwitched.fromJson(map);
      case "user":
        return SessionMessageUser.fromJson(map);
      case "synthetic":
        return SessionMessageSynthetic.fromJson(map);
      case "system":
        return SessionMessageSystem.fromJson(map);
      case "skill":
        return SessionMessageSkill.fromJson(map);
      case "shell":
        return SessionMessageShell.fromJson(map);
      case "assistant":
        return SessionMessageAssistant.fromJson(map);
      case "compaction":
        return SessionMessageCompaction.fromJson(map);
      case "idle":
        return SessionMessageIdle.fromJson(map);
      default:
        return SessionMessageInfoUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [SessionMessageInfo] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class SessionMessageInfoUnknown implements SessionMessageInfo {
  const SessionMessageInfoUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageInfoUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

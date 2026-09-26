// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_tool_state_completed.g.dart';
import 'session_message_tool_state_error.g.dart';
import 'session_message_tool_state_running.g.dart';
import 'session_message_tool_state_streaming.g.dart';

@immutable
abstract interface class SessionMessageToolState {
  const SessionMessageToolState();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory SessionMessageToolState.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["status"];
    switch (discriminator) {
      case "streaming":
        return SessionMessageToolStateStreaming.fromJson(map);
      case "running":
        return SessionMessageToolStateRunning.fromJson(map);
      case "completed":
        return SessionMessageToolStateCompleted.fromJson(map);
      case "error":
        return SessionMessageToolStateError.fromJson(map);
      default:
        return SessionMessageToolStateUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [SessionMessageToolState] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class SessionMessageToolStateUnknown implements SessionMessageToolState {
  const SessionMessageToolStateUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageToolStateUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

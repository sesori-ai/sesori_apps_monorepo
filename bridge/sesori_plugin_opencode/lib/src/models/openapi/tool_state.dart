// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.203849Z

import 'tool_state_completed.dart';
import 'tool_state_error.dart';
import 'tool_state_pending.dart';
import 'tool_state_running.dart';

abstract interface class ToolState {
  const ToolState();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `dynamic` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `dynamic`.
  Object? toJson();

  factory ToolState.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["status"];
    switch (discriminator) {
      case "pending":
        return ToolStatePending.fromJson(map);
      case "running":
        return ToolStateRunning.fromJson(map);
      case "completed":
        return ToolStateCompleted.fromJson(map);
      case "error":
        return ToolStateError.fromJson(map);
      default:
        throw FormatException('Unknown ToolState value: $discriminator');
    }
  }
}

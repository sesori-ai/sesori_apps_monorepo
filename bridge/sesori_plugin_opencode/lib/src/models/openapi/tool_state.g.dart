// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_state_completed.g.dart';
import 'tool_state_error.g.dart';
import 'tool_state_pending.g.dart';
import 'tool_state_running.g.dart';

@immutable
abstract interface class ToolState {
  const ToolState();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
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
        return ToolStateUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [ToolState] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class ToolStateUnknown implements ToolState {
  const ToolStateUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

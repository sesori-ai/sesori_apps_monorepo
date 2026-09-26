// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message_compaction_completed.g.dart';
import 'session_message_compaction_failed.g.dart';
import 'session_message_compaction_running.g.dart';
import 'session_message_info.g.dart';

@immutable
abstract interface class SessionMessageCompaction implements SessionMessageInfo {
  const SessionMessageCompaction();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory SessionMessageCompaction.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["status"];
    switch (discriminator) {
      case "running":
        return SessionMessageCompactionRunning.fromJson(map);
      case "completed":
        return SessionMessageCompactionCompleted.fromJson(map);
      case "failed":
        return SessionMessageCompactionFailed.fromJson(map);
      default:
        return SessionMessageCompactionUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [SessionMessageCompaction] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class SessionMessageCompactionUnknown implements SessionMessageCompaction {
  const SessionMessageCompactionUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageCompactionUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

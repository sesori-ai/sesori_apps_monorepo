// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'agent_part.g.dart';
import 'compaction_part.g.dart';
import 'file_part.g.dart';
import 'patch_part.g.dart';
import 'reasoning_part.g.dart';
import 'retry_part.g.dart';
import 'snapshot_part.g.dart';
import 'step_finish_part.g.dart';
import 'step_start_part.g.dart';
import 'subtask_part.g.dart';
import 'text_part.g.dart';
import 'tool_part.g.dart';

@immutable
abstract interface class Part {
  const Part();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory Part.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "text":
        return TextPart.fromJson(map);
      case "subtask":
        return SubtaskPart.fromJson(map);
      case "reasoning":
        return ReasoningPart.fromJson(map);
      case "file":
        return FilePart.fromJson(map);
      case "tool":
        return ToolPart.fromJson(map);
      case "step-start":
        return StepStartPart.fromJson(map);
      case "step-finish":
        return StepFinishPart.fromJson(map);
      case "snapshot":
        return SnapshotPart.fromJson(map);
      case "patch":
        return PatchPart.fromJson(map);
      case "agent":
        return AgentPart.fromJson(map);
      case "retry":
        return RetryPart.fromJson(map);
      case "compaction":
        return CompactionPart.fromJson(map);
      default:
        return PartUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [Part] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class PartUnknown implements Part {
  const PartUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

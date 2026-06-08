// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.176870Z

import 'agent_part.dart';
import 'compaction_part.dart';
import 'file_part.dart';
import 'patch_part.dart';
import 'reasoning_part.dart';
import 'retry_part.dart';
import 'snapshot_part.dart';
import 'step_finish_part.dart';
import 'step_start_part.dart';
import 'subtask_part.dart';
import 'text_part.dart';
import 'tool_part.dart';

abstract interface class Part {
  const Part();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `dynamic` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `dynamic`.
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
        throw FormatException('Unknown Part value: $discriminator');
    }
  }
}

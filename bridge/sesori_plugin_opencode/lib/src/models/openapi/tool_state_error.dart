// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_state.dart';

@immutable
class ToolStateError implements ToolState {
  const ToolStateError({
    required this.input,
    required this.error,
    this.metadata,
    required this.time,
  });

  factory ToolStateError.fromJson(Map<String, dynamic> json) {
    return ToolStateError(
      input: json["input"] as Map<String, dynamic>,
      error: json["error"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: ToolStateErrorTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "error",
      "input": input,
      "error": error,
      "metadata": ?metadata,
      "time": time.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateError &&
          const DeepCollectionEquality().equals(other.input, input) &&
          other.error == error &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(input), error, const DeepCollectionEquality().hash(metadata), time);

  final Map<String, dynamic> input;
  final String error;
  final Map<String, dynamic>? metadata;
  final ToolStateErrorTime time;
}

@immutable
class ToolStateErrorTime {
  const ToolStateErrorTime({
    required this.start,
    required this.end,
  });

  factory ToolStateErrorTime.fromJson(Map<String, dynamic> json) {
    return ToolStateErrorTime(
      start: (json["start"] as num).toInt(),
      end: (json["end"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
      "end": end,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateErrorTime &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  final int start;
  final int end;
}

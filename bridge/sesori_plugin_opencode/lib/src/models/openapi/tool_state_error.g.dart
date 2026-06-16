// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_state.g.dart';

@immutable
class ToolStateError implements ToolState {
  const ToolStateError({
    required this.input,
    required this.error,
    required this.metadata,
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolStateError copyWith({
    Map<String, dynamic>? input,
    String? error,
    Map<String, dynamic>? metadata,
    ToolStateErrorTime? time,
  }) {
    return ToolStateError(
      input: input ?? this.input,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
    );
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolStateErrorTime copyWith({
    int? start,
    int? end,
  }) {
    return ToolStateErrorTime(
      start: start ?? this.start,
      end: end ?? this.end,
    );
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

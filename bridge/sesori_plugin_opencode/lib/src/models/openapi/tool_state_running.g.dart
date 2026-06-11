// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_state.g.dart';

@immutable
class ToolStateRunning implements ToolState {
  const ToolStateRunning({
    this.input = const {},
    this.title,
    this.metadata,
    required this.time,
  });

  factory ToolStateRunning.fromJson(Map<String, dynamic> json) {
    return ToolStateRunning(
      input: (json["input"] ?? const <String, dynamic>{}) as Map<String, dynamic>,
      title: json["title"] as String?,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: ToolStateRunningTime.fromJson((json["time"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "running",
      "input": input,
      "title": ?title,
      "metadata": ?metadata,
      "time": time.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolStateRunning copyWith({
    Map<String, dynamic>? input,
    String? title,
    Map<String, dynamic>? metadata,
    ToolStateRunningTime? time,
  }) {
    return ToolStateRunning(
      input: input ?? this.input,
      title: title ?? this.title,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateRunning &&
          const DeepCollectionEquality().equals(other.input, input) &&
          other.title == title &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(input), title, const DeepCollectionEquality().hash(metadata), time);

  final Map<String, dynamic> input;
  final String? title;
  final Map<String, dynamic>? metadata;
  final ToolStateRunningTime time;
}

@immutable
class ToolStateRunningTime {
  const ToolStateRunningTime({
    this.start = 0,
  });

  factory ToolStateRunningTime.fromJson(Map<String, dynamic> json) {
    return ToolStateRunningTime(
      start: ((json["start"] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolStateRunningTime copyWith({
    int? start,
  }) {
    return ToolStateRunningTime(
      start: start ?? this.start,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateRunningTime &&
          other.start == start);

  @override
  int get hashCode => start.hashCode;

  final int start;
}

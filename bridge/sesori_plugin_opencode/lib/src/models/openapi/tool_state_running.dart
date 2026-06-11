// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_state.dart';

@immutable
class ToolStateRunning implements ToolState {
  const ToolStateRunning({
    required this.input,
    this.title,
    this.metadata,
    required this.time,
  });

  factory ToolStateRunning.fromJson(Map<String, dynamic> json) {
    return ToolStateRunning(
      input: json["input"] as Map<String, dynamic>,
      title: json["title"] as String?,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: ToolStateRunningTime.fromJson(json["time"] as Map<String, dynamic>),
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
    required this.start,
  });

  factory ToolStateRunningTime.fromJson(Map<String, dynamic> json) {
    return ToolStateRunningTime(
      start: (json["start"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
    };
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

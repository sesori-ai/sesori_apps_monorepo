// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'file_part.g.dart';
import 'tool_state.g.dart';

@immutable
class ToolStateCompleted implements ToolState {
  const ToolStateCompleted({
    required this.input,
    required this.output,
    required this.title,
    required this.metadata,
    required this.time,
    required this.attachments,
  });

  factory ToolStateCompleted.fromJson(Map<String, dynamic> json) {
    return ToolStateCompleted(
      input: json["input"] as Map<String, dynamic>,
      output: json["output"] as String,
      title: json["title"] as String?,
      metadata: json["metadata"] as Map<String, dynamic>,
      time: ToolStateCompletedTime.fromJson(json["time"] as Map<String, dynamic>),
      attachments: (json["attachments"] as List<dynamic>?)?.map((e) => FilePart.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "completed",
      "input": input,
      "output": output,
      "title": title,
      "metadata": metadata,
      "time": time.toJson(),
      "attachments": ?attachments?.map((e) => e.toJson()).toList(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolStateCompleted copyWith({
    Map<String, dynamic>? input,
    String? output,
    String? title,
    Map<String, dynamic>? metadata,
    ToolStateCompletedTime? time,
    List<FilePart>? attachments,
  }) {
    return ToolStateCompleted(
      input: input ?? this.input,
      output: output ?? this.output,
      title: title ?? this.title,
      metadata: metadata ?? this.metadata,
      time: time ?? this.time,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateCompleted &&
          const DeepCollectionEquality().equals(other.input, input) &&
          other.output == output &&
          other.title == title &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          const DeepCollectionEquality().equals(other.attachments, attachments));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(input), output, title, const DeepCollectionEquality().hash(metadata), time, const DeepCollectionEquality().hash(attachments));

  final Map<String, dynamic> input;
  final String output;
  final String? title;
  final Map<String, dynamic> metadata;
  final ToolStateCompletedTime time;
  final List<FilePart>? attachments;
}

@immutable
class ToolStateCompletedTime {
  const ToolStateCompletedTime({
    required this.start,
    required this.end,
    required this.compacted,
  });

  factory ToolStateCompletedTime.fromJson(Map<String, dynamic> json) {
    return ToolStateCompletedTime(
      start: (json["start"] as num).toInt(),
      end: (json["end"] as num).toInt(),
      compacted: (json["compacted"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": start,
      "end": end,
      "compacted": ?compacted,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolStateCompletedTime copyWith({
    int? start,
    int? end,
    int? compacted,
  }) {
    return ToolStateCompletedTime(
      start: start ?? this.start,
      end: end ?? this.end,
      compacted: compacted ?? this.compacted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateCompletedTime &&
          other.start == start &&
          other.end == end &&
          other.compacted == compacted);

  @override
  int get hashCode => Object.hash(start, end, compacted);

  final int start;
  final int end;
  final int? compacted;
}

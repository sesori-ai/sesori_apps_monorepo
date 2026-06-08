// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.975253Z

import 'package:meta/meta.dart';
import 'file_part.dart';
import 'tool_state.dart';

@immutable
class ToolStateCompleted implements ToolState {
  const ToolStateCompleted({
    required this.input,
    required this.output,
    required this.title,
    required this.metadata,
    required this.time,
    this.attachments,
  });

  factory ToolStateCompleted.fromJson(Map<String, dynamic> json) {
    return ToolStateCompleted(
      input: json["input"] as Map<String, dynamic>,
      output: json["output"] as String,
      title: json["title"] as String,
      metadata: json["metadata"] as Map<String, dynamic>,
      time: json["time"] as Map<String, dynamic>,
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
      "time": time,
      "attachments": ?attachments?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateCompleted &&
          other.input == input &&
          other.output == output &&
          other.title == title &&
          other.metadata == metadata &&
          other.time == time &&
          other.attachments == attachments);

  @override
  int get hashCode => Object.hash(input, output, title, metadata, time, attachments);

  final Map<String, dynamic> input;
  final String output;
  final String title;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> time;
  final List<FilePart>? attachments;
}

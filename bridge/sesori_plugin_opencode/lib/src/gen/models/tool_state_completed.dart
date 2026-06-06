// GENERATED FILE - DO NOT EDIT BY HAND

import 'file_part.dart';
import 'tool_state.dart';

class ToolStateCompleted implements ToolState {
  const ToolStateCompleted({
    required this.status,
    required this.input,
    required this.output,
    required this.title,
    required this.metadata,
    required this.time,
    this.attachments,
  });

  factory ToolStateCompleted.fromJson(Map<String, dynamic> json) {
    return ToolStateCompleted(
      status: json["status"] as String,
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
      "status": status,
      "input": input,
      "output": output,
      "title": title,
      "metadata": metadata,
      "time": time,
      "attachments": attachments,
    };
  }

  final String status;
  final Map<String, dynamic> input;
  final String output;
  final String title;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> time;
  final List<FilePart>? attachments;
}

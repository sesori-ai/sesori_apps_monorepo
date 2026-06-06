// GENERATED FILE - DO NOT EDIT BY HAND

import 'tool_state.dart';

class ToolStateRunning implements ToolState {
  const ToolStateRunning({
    required this.status,
    required this.input,
    this.title,
    this.metadata,
    required this.time,
  });

  factory ToolStateRunning.fromJson(Map<String, dynamic> json) {
    return ToolStateRunning(
      status: json["status"] as String,
      input: json["input"] as Map<String, dynamic>,
      title: json["title"] as String?,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
      "title": title,
      "metadata": metadata,
      "time": time,
    };
  }

  final String status;
  final Map<String, dynamic> input;
  final String? title;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}

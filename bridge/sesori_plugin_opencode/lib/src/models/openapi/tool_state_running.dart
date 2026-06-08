// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.204731Z

import 'tool_state.dart';

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
      time: json["time"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "running",
      "input": input,
      "title": ?title,
      "metadata": ?metadata,
      "time": time,
    };
  }

  final Map<String, dynamic> input;
  final String? title;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}

// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.362192Z

import 'tool_state.dart';

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
      time: json["time"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "error",
      "input": input,
      "error": error,
      "metadata": ?metadata,
      "time": time,
    };
  }

  final Map<String, dynamic> input;
  final String error;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}

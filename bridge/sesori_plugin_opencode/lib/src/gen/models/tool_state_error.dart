// GENERATED FILE - DO NOT EDIT BY HAND

import 'tool_state.dart';

class ToolStateError implements ToolState {
  const ToolStateError({
    required this.status,
    required this.input,
    required this.error,
    this.metadata,
    required this.time,
  });

  factory ToolStateError.fromJson(Map<String, dynamic> json) {
    return ToolStateError(
      status: json["status"] as String,
      input: json["input"] as Map<String, dynamic>,
      error: json["error"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
      "error": error,
      "metadata": metadata,
      "time": time,
    };
  }

  final String status;
  final Map<String, dynamic> input;
  final String error;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}

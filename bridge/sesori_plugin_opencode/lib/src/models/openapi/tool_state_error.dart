// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.975487Z

import 'package:meta/meta.dart';
import 'tool_state.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStateError &&
          other.input == input &&
          other.error == error &&
          other.metadata == metadata &&
          other.time == time);

  @override
  int get hashCode => Object.hash(input, error, metadata, time);

  final Map<String, dynamic> input;
  final String error;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> time;
}

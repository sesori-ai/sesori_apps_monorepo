// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.689802Z

import 'tool_state.dart';

class ToolStatePending implements ToolState {
  const ToolStatePending({
    required this.input,
    required this.raw,
  });

  factory ToolStatePending.fromJson(Map<String, dynamic> json) {
    return ToolStatePending(
      input: json["input"] as Map<String, dynamic>,
      raw: json["raw"] as String,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "pending",
      "input": input,
      "raw": raw,
    };
  }

  final Map<String, dynamic> input;
  final String raw;
}

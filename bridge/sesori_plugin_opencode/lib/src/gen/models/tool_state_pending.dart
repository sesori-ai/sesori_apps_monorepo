// GENERATED FILE - DO NOT EDIT BY HAND

import 'tool_state.dart';

class ToolStatePending implements ToolState {
  const ToolStatePending({
    required this.status,
    required this.input,
    required this.raw,
  });

  factory ToolStatePending.fromJson(Map<String, dynamic> json) {
    return ToolStatePending(
      status: json["status"] as String,
      input: json["input"] as Map<String, dynamic>,
      raw: json["raw"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
      "raw": raw,
    };
  }

  final String status;
  final Map<String, dynamic> input;
  final String raw;
}

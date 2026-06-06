// GENERATED FILE - DO NOT EDIT BY HAND

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

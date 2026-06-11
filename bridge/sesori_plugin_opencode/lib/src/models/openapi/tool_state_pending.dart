// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_state.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolStatePending &&
          const DeepCollectionEquality().equals(other.input, input) &&
          other.raw == raw);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(input), raw);

  final Map<String, dynamic> input;
  final String raw;
}

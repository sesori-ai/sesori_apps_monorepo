// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_state.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ToolStatePending copyWith({
    Map<String, dynamic>? input,
    String? raw,
  }) {
    return ToolStatePending(
      input: input ?? this.input,
      raw: raw ?? this.raw,
    );
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

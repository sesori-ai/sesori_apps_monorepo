// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class ModelCapabilities {
  const ModelCapabilities({
    required this.tools,
    required this.input,
    required this.output,
  });

  factory ModelCapabilities.fromJson(Map<String, dynamic> json) {
    return ModelCapabilities(
      tools: json["tools"] as bool,
      input: (json["input"] as List<dynamic>).cast<String>(),
      output: (json["output"] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "tools": tools,
      "input": input,
      "output": output,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCapabilities copyWith({
    bool? tools,
    List<String>? input,
    List<String>? output,
  }) {
    return ModelCapabilities(
      tools: tools ?? this.tools,
      input: input ?? this.input,
      output: output ?? this.output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCapabilities &&
          other.tools == tools &&
          const DeepCollectionEquality().equals(other.input, input) &&
          const DeepCollectionEquality().equals(other.output, output));

  @override
  int get hashCode => Object.hash(tools, const DeepCollectionEquality().hash(input), const DeepCollectionEquality().hash(output));

  final bool tools;
  final List<String> input;
  final List<String> output;
}

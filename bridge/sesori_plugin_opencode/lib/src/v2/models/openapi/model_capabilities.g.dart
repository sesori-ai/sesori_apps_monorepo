// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_freeform_format.g.dart';

@immutable
class ModelCapabilities {
  const ModelCapabilities({
    required this.tools,
    required this.freeform,
    required this.input,
    required this.output,
    required this.temperature,
  });

  factory ModelCapabilities.fromJson(Map<String, dynamic> json) {
    return ModelCapabilities(
      tools: json["tools"] as bool,
      freeform: (json["freeform"] as List<dynamic>?)?.map((e) => ToolFreeformFormat.fromJson(e as String)).toList(),
      input: (json["input"] as List<dynamic>).cast<String>(),
      output: (json["output"] as List<dynamic>).cast<String>(),
      temperature: json["temperature"] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "tools": tools,
      "freeform": ?freeform?.map((e) => e.toJson()).toList(),
      "input": input,
      "output": output,
      "temperature": ?temperature,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCapabilities copyWith({
    bool? tools,
    List<ToolFreeformFormat>? freeform,
    List<String>? input,
    List<String>? output,
    bool? temperature,
  }) {
    return ModelCapabilities(
      tools: tools ?? this.tools,
      freeform: freeform ?? this.freeform,
      input: input ?? this.input,
      output: output ?? this.output,
      temperature: temperature ?? this.temperature,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCapabilities &&
          other.tools == tools &&
          const DeepCollectionEquality().equals(other.freeform, freeform) &&
          const DeepCollectionEquality().equals(other.input, input) &&
          const DeepCollectionEquality().equals(other.output, output) &&
          other.temperature == temperature);

  @override
  int get hashCode => Object.hash(tools, const DeepCollectionEquality().hash(freeform), const DeepCollectionEquality().hash(input), const DeepCollectionEquality().hash(output), temperature);

  final bool tools;
  final List<ToolFreeformFormat>? freeform;
  final List<String> input;
  final List<String> output;
  final bool? temperature;
}

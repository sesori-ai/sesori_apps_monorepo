// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'jsonschema.g.dart';
import 'output_format.g.dart';

@immutable
class OutputFormatJsonSchema implements OutputFormat {
  const OutputFormatJsonSchema({
    required this.schema,
    required this.retryCount,
  });

  factory OutputFormatJsonSchema.fromJson(Map<String, dynamic> json) {
    return OutputFormatJsonSchema(
      schema: JSONSchema.fromJson(json["schema"] as Map<String, dynamic>),
      retryCount: (json["retryCount"] as num?)?.toInt(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "json_schema",
      "schema": schema.toJson(),
      "retryCount": ?retryCount,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  OutputFormatJsonSchema copyWith({
    JSONSchema? schema,
    int? retryCount,
  }) {
    return OutputFormatJsonSchema(
      schema: schema ?? this.schema,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutputFormatJsonSchema &&
          other.schema == schema &&
          other.retryCount == retryCount);

  @override
  int get hashCode => Object.hash(schema, retryCount);

  final JSONSchema schema;
  final int? retryCount;
}

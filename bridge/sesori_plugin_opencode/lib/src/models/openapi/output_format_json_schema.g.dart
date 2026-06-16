// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

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

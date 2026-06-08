// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.944332Z

import 'package:meta/meta.dart';
import 'jsonschema.dart';
import 'output_format.dart';

@immutable
class OutputFormatJsonSchema implements OutputFormat {
  const OutputFormatJsonSchema({
    required this.schema,
    this.retryCount,
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

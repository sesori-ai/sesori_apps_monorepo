// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.664655Z

import 'jsonschema.dart';
import 'output_format.dart';

class OutputFormatJsonSchema implements OutputFormat {
  const OutputFormatJsonSchema({
    required this.schema,
    this.retryCount,
  });

  factory OutputFormatJsonSchema.fromJson(Map<String, dynamic> json) {
    return OutputFormatJsonSchema(
      schema: JSONSchema.fromJson(json["schema"] as Map<String, dynamic>),
      retryCount: json["retryCount"] as int?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "json_schema",
      "schema": schema.toJson(),
      "retryCount": retryCount,
    };
  }

  final JSONSchema schema;
  final int? retryCount;
}

// GENERATED FILE - DO NOT EDIT BY HAND

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

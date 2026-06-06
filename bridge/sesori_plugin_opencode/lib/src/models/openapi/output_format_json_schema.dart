// GENERATED FILE - DO NOT EDIT BY HAND

import 'jsonschema.dart';
import 'output_format.dart';

class OutputFormatJsonSchema implements OutputFormat {
  const OutputFormatJsonSchema({
    required this.type,
    required this.schema,
    this.retryCount,
  });

  factory OutputFormatJsonSchema.fromJson(Map<String, dynamic> json) {
    return OutputFormatJsonSchema(
      type: json["type"] as String,
      schema: JSONSchema.fromJson(json["schema"] as Map<String, dynamic>),
      retryCount: json["retryCount"] as int?,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "schema": schema.toJson(),
      "retryCount": retryCount,
    };
  }

  final String type;
  final JSONSchema schema;
  final int? retryCount;
}

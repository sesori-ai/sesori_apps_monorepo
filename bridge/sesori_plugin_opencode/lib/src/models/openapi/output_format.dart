// GENERATED FILE - DO NOT EDIT BY HAND

import 'output_format_json_schema.dart';
import 'output_format_text.dart';

abstract interface class OutputFormat {
  const OutputFormat();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory OutputFormat.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      case "text":
        return OutputFormatText.fromJson(json);
      case "json_schema":
        return OutputFormatJsonSchema.fromJson(json);
      default:
        throw FormatException('Unknown OutputFormat value: $discriminator');
    }
  }
}

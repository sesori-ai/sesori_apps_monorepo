// GENERATED FILE - DO NOT EDIT BY HAND

import 'output_format_json_schema.dart';
import 'output_format_text.dart';

abstract interface class OutputFormat {
  const OutputFormat();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `dynamic` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `dynamic`.
  dynamic toJson();

  factory OutputFormat.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "text":
        return OutputFormatText.fromJson(map);
      case "json_schema":
        return OutputFormatJsonSchema.fromJson(map);
      default:
        throw FormatException('Unknown OutputFormat value: $discriminator');
    }
  }
}

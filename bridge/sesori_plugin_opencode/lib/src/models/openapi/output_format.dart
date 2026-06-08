// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.233289Z

import 'package:meta/meta.dart';
import 'output_format_json_schema.dart';
import 'output_format_text.dart';

@immutable
abstract interface class OutputFormat {
  const OutputFormat();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory OutputFormat.fromJson(Object json) {
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

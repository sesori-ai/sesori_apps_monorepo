// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_file_content.g.dart';
import 'tool_text_content.g.dart';

@immutable
abstract interface class ToolContent {
  const ToolContent();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory ToolContent.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "text":
        return ToolTextContent.fromJson(map);
      case "file":
        return ToolFileContent.fromJson(map);
      default:
        return ToolContentUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [ToolContent] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class ToolContentUnknown implements ToolContent {
  const ToolContentUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolContentUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

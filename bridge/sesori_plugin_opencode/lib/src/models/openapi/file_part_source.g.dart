// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'file_source.g.dart';
import 'resource_source.g.dart';
import 'symbol_source.g.dart';

@immutable
abstract interface class FilePartSource {
  const FilePartSource();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory FilePartSource.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "file":
        return FileSource.fromJson(map);
      case "symbol":
        return SymbolSource.fromJson(map);
      case "resource":
        return ResourceSource.fromJson(map);
      default:
        return FilePartSourceUnknown(raw: map);
    }
  }
}

/// Fallback variant for an unrecognized [FilePartSource] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class FilePartSourceUnknown implements FilePartSource {
  const FilePartSourceUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilePartSourceUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

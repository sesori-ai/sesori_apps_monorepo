// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.225752Z

import 'package:meta/meta.dart';
import 'file_source.dart';
import 'resource_source.dart';
import 'symbol_source.dart';

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
        throw FormatException('Unknown FilePartSource value: $discriminator');
    }
  }
}

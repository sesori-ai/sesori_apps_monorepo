// GENERATED FILE - DO NOT EDIT BY HAND

import 'file_source.dart';
import 'resource_source.dart';
import 'symbol_source.dart';

abstract interface class FilePartSource {
  const FilePartSource();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory FilePartSource.fromJson(dynamic json) {
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

// GENERATED FILE - DO NOT EDIT BY HAND

import 'file_source.dart';
import 'resource_source.dart';
import 'symbol_source.dart';

abstract interface class FilePartSource {
  const FilePartSource();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory FilePartSource.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      case "file":
        return FileSource.fromJson(json);
      case "symbol":
        return SymbolSource.fromJson(json);
      case "resource":
        return ResourceSource.fromJson(json);
      default:
        throw FormatException('Unknown FilePartSource value: $discriminator');
    }
  }
}

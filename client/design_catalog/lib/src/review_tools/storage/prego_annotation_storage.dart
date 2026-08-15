import "package:flutter/foundation.dart";

import "prego_annotation_storage_access.dart";
import "prego_annotation_storage_stub.dart"
    if (dart.library.js_interop) "prego_annotation_storage_web.dart"
    as platform;

final class PregoAnnotationStorage._({
  required PregoAnnotationStorageRead read,
  required PregoAnnotationStorageWrite write,
}) {
  final PregoAnnotationStorageRead _read = read;
  final PregoAnnotationStorageWrite _write = write;

  factory forPlatform() {
    final access = platform.createPregoAnnotationStorageAccess();
    return PregoAnnotationStorage._(read: access.read, write: access.write);
  }

  @visibleForTesting
  factory test({
    required PregoAnnotationStorageRead read,
    required PregoAnnotationStorageWrite write,
  }) => PregoAnnotationStorage._(read: read, write: write);

  Future<String?> read({required String key}) => _read(key);
  Future<void> write({required String key, required String value}) => _write(key, value);
}

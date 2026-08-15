import "prego_annotation_storage_access.dart";

PregoAnnotationStorageAccess createPregoAnnotationStorageAccess() {
  final values = <String, String>{};
  return PregoAnnotationStorageAccess(
    read: (key) async => values[key],
    write: (key, value) async => values[key] = value,
  );
}

import "prego_annotation_storage_access.dart";

PregoAnnotationStorageAccess createPregoAnnotationStorageAccess() {
  final values = <String, String>{};
  return PregoAnnotationStorageAccess(
    read: ({required key}) async => values[key],
    write: ({required key, required value}) async => values[key] = value,
  );
}

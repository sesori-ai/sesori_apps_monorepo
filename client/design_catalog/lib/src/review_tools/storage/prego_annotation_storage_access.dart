typedef PregoAnnotationStorageRead = Future<String?> Function({required String key});
typedef PregoAnnotationStorageWrite = Future<void> Function({required String key, required String value});

final class const PregoAnnotationStorageAccess({
  required final PregoAnnotationStorageRead read,
  required final PregoAnnotationStorageWrite write,
});

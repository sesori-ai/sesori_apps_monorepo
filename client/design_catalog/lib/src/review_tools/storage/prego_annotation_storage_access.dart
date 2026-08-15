typedef PregoAnnotationStorageRead = Future<String?> Function(String key);
typedef PregoAnnotationStorageWrite = Future<void> Function(String key, String value);

final class const PregoAnnotationStorageAccess({
  required final PregoAnnotationStorageRead read,
  required final PregoAnnotationStorageWrite write,
});

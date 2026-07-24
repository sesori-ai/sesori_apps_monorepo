import "dart:io";

/// Raw filesystem access for Cursor's persisted ACP session directories.
class CursorSessionStorageApi {
  const CursorSessionStorageApi();

  FileSystemEntityType entityType({required String path}) {
    return FileSystemEntity.typeSync(path, followLinks: false);
  }

  Future<void> deleteDirectory({required String path}) {
    return Directory(path).delete(recursive: true);
  }
}

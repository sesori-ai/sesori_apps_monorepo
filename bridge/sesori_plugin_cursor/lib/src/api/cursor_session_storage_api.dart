import "dart:io";

/// Raw filesystem access for Cursor's persisted ACP session directories.
class CursorSessionStorageApi {
  const CursorSessionStorageApi();

  bool directoryExists({required String path}) {
    return Directory(path).existsSync();
  }

  Future<void> deleteDirectory({required String path}) {
    return Directory(path).delete(recursive: true);
  }
}

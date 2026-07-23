import "dart:io" show FileSystemEntityType;

import "../api/cursor_session_storage_api.dart";

enum CursorSessionStorageEntryType { missing, directory, nonDirectory }

/// Layer-2 access to Cursor's persisted ACP session storage.
class CursorSessionStorageRepository {
  CursorSessionStorageRepository({
    required CursorSessionStorageApi api,
  }) : _api = api;

  final CursorSessionStorageApi _api;

  CursorSessionStorageEntryType entryType({required String path}) {
    final type = _api.entityType(path: path);
    if (type == FileSystemEntityType.notFound) {
      return CursorSessionStorageEntryType.missing;
    }
    if (type == FileSystemEntityType.directory) {
      return CursorSessionStorageEntryType.directory;
    }
    return CursorSessionStorageEntryType.nonDirectory;
  }

  Future<void> deleteDirectory({required String path}) {
    return _api.deleteDirectory(path: path);
  }
}

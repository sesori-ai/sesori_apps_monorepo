import "../api/cursor_session_storage_api.dart";

/// Layer-2 access to Cursor's persisted ACP session storage.
class CursorSessionStorageRepository {
  CursorSessionStorageRepository({
    required CursorSessionStorageApi api,
  }) : _api = api;

  final CursorSessionStorageApi _api;

  bool directoryExists({required String path}) {
    return _api.directoryExists(path: path);
  }

  Future<void> deleteDirectory({required String path}) {
    return _api.deleteDirectory(path: path);
  }
}

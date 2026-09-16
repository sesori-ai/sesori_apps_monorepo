/// The result of a local protected-file readability check, not a remote bridge check.
enum FileAccessStatus() {
  unknown,
  granted,
  denied,
  unsupported,
}

abstract interface class FileAccessPermission() {
  Future<FileAccessStatus> check();

  Future<void> openSystemSettings();
}

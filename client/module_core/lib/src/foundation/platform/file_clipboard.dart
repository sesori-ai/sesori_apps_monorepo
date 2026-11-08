/// Reads the files copied in the platform's file manager.
abstract interface class FileClipboard() {
  /// Paths of the copied files on this computer, or an empty list when the
  /// clipboard holds none.
  Future<List<String>> readPaths();
}

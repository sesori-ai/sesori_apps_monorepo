import "dart:io";

/// Layer 1 data access over the host filesystem (`dart:io`).
///
/// Each method is a thin wrapper around a single `dart:io` operation. They
/// return raw results and may throw [FileSystemException] (including OS-level
/// permission denials). No classification, mapping, or decision-making lives
/// here — that belongs in [FilesystemRepository].
class FilesystemApi {
  const FilesystemApi();

  /// Returns the type of the entity at [path] (or [FileSystemEntityType.notFound]).
  FileSystemEntityType entityType(String path) {
    return FileSystemEntity.typeSync(path, followLinks: false);
  }

  /// Whether a directory exists at [path].
  bool directoryExists(String path) {
    return Directory(path).existsSync();
  }

  /// The parent directory path of [path].
  String parentPath(String path) {
    return Directory(path).parent.path;
  }

  /// Creates the directory at [path] (non-recursive).
  void createDirectory(String path) {
    Directory(path).createSync(recursive: false);
  }

  /// Lists the immediate child directories of [path].
  List<Directory> listDirectories(String path) {
    return Directory(path).listSync(followLinks: false).whereType<Directory>().toList();
  }

  /// Whether [directoryPath] contains a `.git` entry (a git working copy).
  bool gitDirectoryExists(String directoryPath) {
    return Directory("$directoryPath/.git").existsSync();
  }

  /// Reads the file at [path], or `null` if it does not exist.
  String? readFileIfExists(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsStringSync();
  }

  String resolveFilePath(String path) {
    return File(path).resolveSymbolicLinksSync();
  }

  String resolveDirectoryPath(String path) {
    return Directory(path).resolveSymbolicLinksSync();
  }

  int fileLength(String path) {
    return File(path).lengthSync();
  }

  String readFileAsString(String path) {
    return File(path).readAsStringSync();
  }

  List<int> readFileAsBytes(String path) {
    return File(path).readAsBytesSync();
  }

  /// Appends [content] to the file at [path], creating it if needed.
  void appendToFile(String path, String content) {
    File(path).writeAsStringSync(content, mode: FileMode.append);
  }
}

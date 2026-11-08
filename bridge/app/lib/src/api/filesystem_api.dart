import "dart:io";

import "package:path/path.dart" as p;

import "../foundation/data_directory_hardening.dart";

/// Layer 1 data access over the host filesystem (`dart:io`).
///
/// Each method is a thin wrapper around a single `dart:io` operation. They
/// return raw results and may throw [FileSystemException] (including OS-level
/// permission denials). No classification, mapping, or decision-making lives
/// here — that belongs in [FilesystemRepository].
class const FilesystemApi() {
  /// Returns the type of the entity at [path] (or [FileSystemEntityType.notFound]).
  FileSystemEntityType entityType({required String path}) {
    return FileSystemEntity.typeSync(path, followLinks: false);
  }

  /// Whether a directory exists at [path].
  bool directoryExists({required String path}) {
    return Directory(path).existsSync();
  }

  /// The parent directory path of [path].
  String parentPath({required String path}) {
    return Directory(path).parent.path;
  }

  /// Creates the directory at [path] (non-recursive).
  void createDirectory({required String path}) {
    Directory(path).createSync(recursive: false);
  }

  /// Lists the immediate child directories of [path].
  List<Directory> listDirectories({required String path}) {
    return Directory(path).listSync(followLinks: false).whereType<Directory>().toList();
  }

  /// Asynchronous [listDirectories], so a large or slow folder does not block
  /// the isolate.
  Future<List<Directory>> listDirectoriesAsync({required String path}) async {
    final entries = await Directory(path).list(followLinks: false).toList();
    return entries.whereType<Directory>().toList();
  }

  /// Whether [directoryPath] contains a `.git` entry (a git working copy).
  bool gitDirectoryExists({required String directoryPath}) {
    final type = FileSystemEntity.typeSync(
      p.join(directoryPath, ".git"),
      followLinks: true,
    );
    return type == FileSystemEntityType.directory || type == FileSystemEntityType.file;
  }

  /// Asynchronous [directoryExists], for probes that may stall on a
  /// disconnected drive and must not block the isolate meanwhile.
  Future<bool> directoryExistsAsync({required String path}) {
    // The async call is the point: a stalled probe runs off the isolate.
    // ignore: avoid_slow_async_io
    return Directory(path).exists();
  }

  /// Raw process environment for repository-level fallback policy.
  Map<String, String> get environment => Platform.environment;

  /// Raw process working directory for repository-level fallback policy.
  String currentDirectoryPath() => Directory.current.path;

  /// Immediate entry names in [path].
  List<String> listEntryNames({required String path}) {
    return Directory(path).listSync(followLinks: false).map((entry) => p.basename(entry.path)).toList();
  }

  /// Streams at most [maximumEntries] immediate entry names from [path].
  Future<List<String>> listEntryNamesBounded({required String path, required int maximumEntries}) async {
    if (maximumEntries <= 0) {
      throw ArgumentError.value(maximumEntries, "maximumEntries", "must be positive");
    }

    final names = <String>[];
    await for (final entry in Directory(path).list(followLinks: false)) {
      names.add(p.basename(entry.path));
      if (names.length == maximumEntries) break;
    }
    return names;
  }

  /// Deletes [path] and all descendants.
  void deleteDirectoryRecursively({required String path}) {
    Directory(path).deleteSync(recursive: true);
  }

  /// Asynchronous [deleteDirectoryRecursively], so a large folder does not
  /// block the isolate. Links inside [path] are removed, never followed.
  Future<void> deleteDirectoryRecursivelyAsync({required String path}) async {
    await Directory(path).delete(recursive: true);
  }

  /// Creates the directory at [path] and any missing parents; a no-op when it
  /// already exists.
  Future<void> createDirectoryRecursively({required String path}) async {
    await Directory(path).create(recursive: true);
  }

  /// Creates a new directory in [parent] whose name is [prefix] followed by
  /// random characters, and returns its path.
  Future<String> createTemporaryDirectory({required String parent, required String prefix}) async {
    final directory = await Directory(parent).createTemp(prefix);
    return directory.path;
  }

  /// Writes [bytes] to the file at [path], which only the current user can
  /// read or write, and flushes it to disk before completing.
  Future<void> writeOwnerOnlyFile({required String path, required List<int> bytes}) async {
    final file = await File(path).create();
    await hardenPath(targetPath: path, mode: ownerOnlyFileMode);
    await file.writeAsBytes(bytes, flush: true);
  }

  /// Creates the directory at [path] and any missing parents, then lets only
  /// the current user open it. Hardens an existing directory too.
  Future<void> createOwnerOnlyDirectory({required String path}) async {
    await Directory(path).create(recursive: true);
    await hardenPath(targetPath: path, mode: ownerOnlyDirectoryMode);
  }

  /// [createTemporaryDirectory], but only the current user can open the new
  /// directory. When hardening fails, removes the directory and rethrows.
  Future<String> createOwnerOnlyTemporaryDirectory({required String parent, required String prefix}) async {
    final directory = await Directory(parent).createTemp(prefix);
    try {
      await hardenPath(targetPath: directory.path, mode: ownerOnlyDirectoryMode);
    } on Object {
      await directory.delete(recursive: true);
      rethrow;
    }
    return directory.path;
  }

  String resolveFilePath({required String path}) {
    return File(path).resolveSymbolicLinksSync();
  }

  String resolveDirectoryPath({required String path}) {
    return Directory(path).resolveSymbolicLinksSync();
  }

  List<int> readFilePrefix({required String path, required int maxBytes}) {
    final file = File(path).openSync();
    try {
      final bytes = <int>[];
      while (bytes.length <= maxBytes) {
        final chunk = file.readSync(maxBytes + 1 - bytes.length);
        if (chunk.isEmpty) break;
        bytes.addAll(chunk);
      }
      return bytes;
    } finally {
      file.closeSync();
    }
  }
}

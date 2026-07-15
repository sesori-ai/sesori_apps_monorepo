import "dart:io";

import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:test/test.dart";

void main() {
  group("FilesystemRepository", () {
    late Directory tempDir;
    late FilesystemRepository repository;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("fs_repo_test_");
      repository = FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test("directoryExists delegates directory probes", () {
      expect(repository.directoryExists(path: tempDir.path), isTrue);
      expect(repository.directoryExists(path: "${tempDir.path}/missing"), isFalse);
    });

    test("listSuggestions maps directories and flags git repos", () {
      Directory("${tempDir.path}/plain").createSync();
      final repo = Directory("${tempDir.path}/with_git")..createSync();
      Directory("${repo.path}/.git").createSync();

      final result = repository.listSuggestions(prefix: tempDir.path, maxResults: 10);

      expect(result.data, hasLength(2));
      final byName = {for (final s in result.data) s.name: s};
      expect(byName["plain"]!.isGitRepo, isFalse);
      expect(byName["with_git"]!.isGitRepo, isTrue);
    });

    test("listSuggestions throws not-found for a missing prefix", () {
      expect(
        () => repository.listSuggestions(prefix: "${tempDir.path}/missing", maxResults: 10),
        throwsA(isA<FilesystemDirectoryNotFoundException>()),
      );
    });

    test("classifyPath distinguishes directories, files, and missing paths", () {
      final file = File("${tempDir.path}/a.txt")..createSync();
      expect(repository.classifyPath(path: tempDir.path), FilesystemEntityKind.directory);
      expect(repository.classifyPath(path: file.path), FilesystemEntityKind.notDirectory);
      expect(repository.classifyPath(path: "${tempDir.path}/none"), FilesystemEntityKind.notFound);
    });

    test("listSuggestions returns deterministic alphabetical top-N when truncating", () {
      for (final name in ["c", "a", "d", "b"]) {
        Directory("${tempDir.path}/$name").createSync();
      }

      final result = repository.listSuggestions(prefix: tempDir.path, maxResults: 2);

      expect(result.data.map((s) => s.name).toList(), ["a", "b"]);
    });

    test("translates a permission denial into FilesystemPermissionDeniedException", () {
      final repo = FilesystemRepository(
        filesystemApi: _PermissionDeniedFilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(
        () => repo.listSuggestions(prefix: "/protected", maxResults: 10),
        throwsA(
          isA<FilesystemPermissionDeniedException>().having((e) => e.path, "path", "/protected"),
        ),
      );
    });

    test("classifyPath probes readability and reports a permission denial", () {
      // A directory that stats fine but cannot be listed (e.g. macOS Full Disk
      // Access denial) must surface as a permission denial, not a plain
      // directory, so the open-project path returns 403.
      final repo = FilesystemRepository(
        filesystemApi: _PermissionDeniedFilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(
        () => repo.classifyPath(path: "/protected"),
        throwsA(isA<FilesystemPermissionDeniedException>()),
      );
    });
  });
}

/// Fake that reports the directory exists but raises an EACCES on listing.
class _PermissionDeniedFilesystemApi implements FilesystemApi {
  @override
  bool directoryExists(String path) => true;

  @override
  List<Directory> listDirectories(String path) {
    throw FileSystemException("denied", path, const OSError("Permission denied", 13));
  }

  @override
  FileSystemEntityType entityType(String path) => FileSystemEntityType.directory;

  @override
  String parentPath(String path) => "/";

  @override
  void createDirectory(String path) {}

  @override
  bool gitDirectoryExists(String directoryPath) => false;

  @override
  String? readFileIfExists(String path) => null;

  @override
  int fileLength(String path) => throw UnimplementedError();

  @override
  List<int> readFileAsBytes(String path) => throw UnimplementedError();

  @override
  String readFileAsString(String path) => throw UnimplementedError();

  @override
  String resolveDirectoryPath(String path) => throw UnimplementedError();

  @override
  String resolveFilePath(String path) => throw UnimplementedError();

  @override
  void appendToFile(String path, String content) {}
}

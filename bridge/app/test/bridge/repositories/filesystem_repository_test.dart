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

    test("reads SVG files as bounded text", () {
      File("${tempDir.path}/icon.svg").writeAsStringSync("<svg></svg>");

      final result = repository.readBoundedTextFile(
        rootDirectoryPath: tempDir.path,
        relativePath: "icon.svg",
        maxBytes: 100,
      );

      expect(result, isA<BoundedTextFileContent>());
    });

    test("returns read failure for symlinks instead of missing content", () {
      File("${tempDir.path}/target.txt").writeAsStringSync("target");
      Link("${tempDir.path}/link.txt").createSync("${tempDir.path}/target.txt");

      final result = repository.readBoundedTextFile(
        rootDirectoryPath: tempDir.path,
        relativePath: "link.txt",
        maxBytes: 100,
      );

      expect(result, isA<BoundedTextFileReadFailure>());
    });

    test("classifies a max-plus-one prefix as too large", () {
      final growingRepository = FilesystemRepository(
        filesystemApi: _GrowingFilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      final result = growingRepository.readBoundedTextFile(
        rootDirectoryPath: "/root",
        relativePath: "growing.txt",
        maxBytes: 5,
      );

      expect(result, isA<BoundedTextFileTooLarge>());
    });

    test("listSuggestions maps directories and flags git repos", () {
      Directory("${tempDir.path}/plain").createSync();
      final repo = Directory("${tempDir.path}/with_git")..createSync();
      Directory("${repo.path}/.git").createSync();
      final worktree = Directory("${tempDir.path}/worktree")..createSync();
      File("${worktree.path}/.git").writeAsStringSync("gitdir: ../.git/worktrees/worktree");

      final result = repository.listSuggestions(prefix: tempDir.path, maxResults: 10);

      expect(result.data, hasLength(3));
      final byName = {for (final s in result.data) s.name: s};
      expect(byName["plain"]!.isGitRepo, isFalse);
      expect(byName["with_git"]!.isGitRepo, isTrue);
      expect(byName["worktree"]!.isGitRepo, isTrue);
    });

    test("defaultBrowsePath skips empty environment values", () {
      final repo = FilesystemRepository(
        filesystemApi: _EnvironmentFilesystemApi(
          environment: {"HOME": "", "USERPROFILE": r"C:\Users\dev"},
          currentDirectory: "/fallback",
        ),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(repo.defaultBrowsePath, r"C:\Users\dev");
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
  String currentDirectoryPath() => "/";

  @override
  void deleteDirectoryRecursively(String path) {}

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
  String? environmentValue(String name) => null;

  @override
  List<String> listEntryNames(String path) => throw UnimplementedError();

  @override
  String? readFileIfExists(String path) => null;

  @override
  List<int> readFilePrefix({required String path, required int maxBytes}) => throw UnimplementedError();

  @override
  String resolveDirectoryPath(String path) => throw UnimplementedError();

  @override
  String resolveFilePath(String path) => throw UnimplementedError();

  @override
  void appendToFile(String path, String content) {}
}

class _GrowingFilesystemApi implements FilesystemApi {
  @override
  FileSystemEntityType entityType(String path) => FileSystemEntityType.file;

  @override
  List<int> readFilePrefix({required String path, required int maxBytes}) => "123456".codeUnits;

  @override
  String resolveDirectoryPath(String path) => path;

  @override
  String resolveFilePath(String path) => path;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EnvironmentFilesystemApi implements FilesystemApi {
  final Map<String, String> environment;
  final String currentDirectory;

  _EnvironmentFilesystemApi({required this.environment, required this.currentDirectory});

  @override
  String currentDirectoryPath() => currentDirectory;

  @override
  String? environmentValue(String name) => environment[name];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

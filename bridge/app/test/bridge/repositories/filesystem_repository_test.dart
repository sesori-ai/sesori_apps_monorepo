import "dart:async";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
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

    test("listDriveRoots is empty on a host other than Windows, macOS, or Linux", () async {
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(isWindows: false, probes: {r"C:\": Future.value(true)}),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(await repo.listDriveRoots(), isEmpty);
    });

    test("listDriveRoots lists mounted Windows drives in letter order", () async {
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(
          isWindows: true,
          probes: {r"D:\": Future.value(true), r"C:\": Future.value(true), r"E:\": Future.value(false)},
        ),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(await repo.listDriveRoots(), [r"C:\", r"D:\"]);
    });

    test("listDriveRoots omits a drive whose probe fails and keeps the others", () async {
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(
          isWindows: true,
          probes: {
            r"C:\": Future.value(true),
            r"E:\": Future<bool>(() => throw const FileSystemException("Access is denied", r"E:\")),
            r"F:\": Future.value(true),
          },
        ),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(await repo.listDriveRoots(), [r"C:\", r"F:\"]);
    });

    test("listDriveRoots skips a drive whose probe stalls", () {
      fakeAsync((async) {
        final repo = FilesystemRepository(
          filesystemApi: _DriveFilesystemApi(
            isWindows: true,
            probes: {r"C:\": Future.value(true), r"Z:\": Completer<bool>().future},
          ),
          permissionValidator: const FilesystemPermissionValidator(),
        );

        List<String>? roots;
        unawaited(repo.listDriveRoots().then((value) => roots = value));
        async.elapse(const Duration(seconds: 1));
        expect(roots, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(roots, [r"C:\"]);
      });
    });

    test("listDriveRoots lists writable Finder-visible macOS volumes", () async {
      const mountTable = """
/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)
/dev/disk3s3 on /Volumes/Recovery (apfs, local, journaled, nobrowse)
/dev/disk5s1 on /Volumes/Work SSD (apfs, local, nodev, nosuid, journaled, noowners)
/dev/disk6s2 on /Volumes/Some App (hfs, local, nodev, nosuid, read-only, noowners, quarantine, mounted by dev)
//dev@nas/share on /Volumes/share (smbfs, nodev, nosuid, mounted by dev)
/dev/disk4s1 on /Volumes/Archive (apfs, local, nodev, nosuid, journaled, noowners)
""";
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(
          isWindows: false,
          isMacOS: true,
          mountTable: () async => mountTable,
          probes: {
            "/Volumes/Work SSD": Future.value(true),
            "/Volumes/share": Future.value(true),
            "/Volumes/Archive": Future.value(true),
            "/Volumes/Recovery": Future.value(true),
            "/Volumes/Some App": Future.value(true),
          },
        ),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(await repo.listDriveRoots(), ["/Volumes/Archive", "/Volumes/Work SSD", "/Volumes/share"]);
    });

    test("listDriveRoots lists writable Linux mounts, leaving out WSL plumbing", () async {
      const mountTable = r"""
/dev/sda2 / ext4 rw,relatime 0 0
/dev/sdb1 /media/dev/Data\040Disk ext4 rw,nosuid,nodev 0 0
/dev/sr0 /media/dev/Ubuntu iso9660 ro,nosuid,nodev 0 0
/dev/sdc1 /run/media/dev/USB vfat rw,nosuid,nodev 0 0
none /mnt/wslg tmpfs rw,relatime 0 0
none /mnt/wslg/doc overlay rw,relatime 0 0
C:\134 /mnt/c 9p rw,noatime 0 0
""";
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(
          isWindows: false,
          isLinux: true,
          mountTable: () async => mountTable,
          probes: {
            "/media/dev/Data Disk": Future.value(true),
            "/media/dev/Ubuntu": Future.value(true),
            "/run/media/dev/USB": Future.value(true),
            "/mnt/wslg": Future.value(true),
            "/mnt/wslg/doc": Future.value(true),
            "/mnt/c": Future.value(true),
          },
        ),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(await repo.listDriveRoots(), ["/media/dev/Data Disk", "/mnt/c", "/run/media/dev/USB"]);
    });

    test("listDriveRoots is empty when the mount table cannot be read", () async {
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(
          isWindows: false,
          isMacOS: true,
          mountTable: () => Future.error(const ProcessException("/sbin/mount", [], "failed", 1)),
          probes: const {},
        ),
        permissionValidator: const FilesystemPermissionValidator(),
      );

      expect(await repo.listDriveRoots(), isEmpty);
    });

    for (final existingContent in ["build/", "# .worktrees/", "!.worktrees/"]) {
      test("ensureGitignoreEntry appends an exact rule after '$existingContent'", () {
        final gitignore = File("${tempDir.path}/.gitignore")..writeAsStringSync(existingContent);

        repository.ensureGitignoreEntry(projectPath: tempDir.path, entry: ".worktrees/");

        expect(gitignore.readAsStringSync(), "$existingContent\n.worktrees/\n");
      });
    }

    test("listSuggestions ignores a dangling .git symlink", () {
      final directory = Directory("${tempDir.path}/dangling")..createSync();
      Link("${directory.path}/.git").createSync("${tempDir.path}/missing-git-target");

      final result = repository.listSuggestions(prefix: tempDir.path, maxResults: 10);

      expect(result.data.singleWhere((entry) => entry.name == "dangling").isGitRepo, isFalse);
    });

    test("listSuggestions follows a valid .git symlink", () {
      final gitTarget = Directory("${tempDir.path}/git-target")..createSync();
      final directory = Directory("${tempDir.path}/linked")..createSync();
      Link("${directory.path}/.git").createSync(gitTarget.path);

      final result = repository.listSuggestions(prefix: tempDir.path, maxResults: 10);

      expect(result.data.singleWhere((entry) => entry.name == "linked").isGitRepo, isTrue);
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

    test("listSuggestions returns every child when maxResults exceeds the directory size", () {
      // Guards the reported bug: a directory of 152 folders listed only its
      // first 50 because the client asked for 50. maxResults must be the only
      // bound in this path — no other cap may re-truncate a listing that fits.
      const childCount = 152;
      for (var index = 0; index < childCount; index++) {
        Directory("${tempDir.path}/project-${index.toString().padLeft(3, "0")}").createSync();
      }

      final result = repository.listSuggestions(prefix: tempDir.path, maxResults: 1000);

      expect(result.data, hasLength(childCount));
      expect(result.data.first.name, "project-000");
      expect(result.data.last.name, "project-151");
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
class _PermissionDeniedFilesystemApi() implements FilesystemApi {
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
  Map<String, String> get environment => const {};

  @override
  bool get isWindows => false;

  @override
  bool get isMacOS => false;

  @override
  bool get isLinux => false;

  @override
  Future<String> readMacosMountTable() => throw UnimplementedError();

  @override
  Future<String> readLinuxMountTable() => throw UnimplementedError();

  @override
  Future<bool> directoryExistsAsync(String path) async => true;

  @override
  List<String> listEntryNames(String path) => throw UnimplementedError();

  @override
  Future<List<String>> listEntryNamesBounded({required String path, required int maximumEntries}) =>
      throw UnimplementedError();

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

class _GrowingFilesystemApi() implements FilesystemApi {
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

class _EnvironmentFilesystemApi({
  @override required final Map<String, String> environment,
  required final String currentDirectory,
}) implements FilesystemApi {
  @override
  String currentDirectoryPath() => currentDirectory;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DriveFilesystemApi({
  @override required final bool isWindows,
  required final Map<String, Future<bool>> _probes,
  @override final bool isMacOS = false,
  @override final bool isLinux = false,
  final Future<String> Function() _mountTable = _noMountTable,
}) implements FilesystemApi {
  @override
  Future<bool> directoryExistsAsync(String path) => _probes[path] ?? Future.value(false);

  @override
  Future<String> readMacosMountTable() => _mountTable();

  @override
  Future<String> readLinuxMountTable() => _mountTable();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<String> _noMountTable() => throw UnimplementedError();

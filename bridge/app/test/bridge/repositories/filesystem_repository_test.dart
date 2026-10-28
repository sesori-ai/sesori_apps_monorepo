import "dart:async";
import "dart:convert";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/api/drive_roots_api.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_process_runner.dart";
import "../../helpers/test_drive_roots_api.dart";

void main() {
  group("FilesystemRepository", () {
    late Directory tempDir;
    late FilesystemRepository repository;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("fs_repo_test_");
      repository = FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
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
        driveRootsApi: windowsDriveRootsApi,
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
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(repo.defaultBrowsePath, r"C:\Users\dev");
    });

    test("listDriveRoots lists mounted Windows drives in letter order", () async {
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(
          probes: {r"D:\": Future.value(true), r"C:\": Future.value(true), r"E:\": Future.value(false)},
        ),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(await repo.listDriveRoots(), [r"C:\", r"D:\"]);
    });

    test("listDriveRoots omits a drive whose probe fails and keeps the others", () async {
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(
          probes: {
            r"C:\": Future.value(true),
            r"E:\": Future<bool>(() => throw const FileSystemException("Access is denied", r"E:\")),
            r"F:\": Future.value(true),
          },
        ),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(await repo.listDriveRoots(), [r"C:\", r"F:\"]);
    });

    test("listDriveRoots skips a drive whose probe stalls", () {
      fakeAsync((async) {
        final repo = FilesystemRepository(
          filesystemApi: _DriveFilesystemApi(probes: {r"C:\": Future.value(true), r"Z:\": Completer<bool>().future}),
          permissionValidator: const FilesystemPermissionValidator(),
          driveRootsApi: windowsDriveRootsApi,
        );

        List<String>? roots;
        unawaited(repo.listDriveRoots().then((value) => roots = value));
        async.elapse(const Duration(seconds: 1));
        expect(roots, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(roots, [r"C:\"]);
      });
    });

    test("listDriveRoots probes the volumes macOS mount lists", () async {
      final processRunner = RecordingProcessRunner(
        stdout: """
/dev/disk3s3 on /Volumes/Recovery (apfs, local, journaled, nobrowse)
/dev/disk5s1 on /Volumes/Work SSD (apfs, local, nodev, nosuid, journaled, noowners)
//dev@nas/share on /Volumes/share (smbfs, nodev, nosuid, mounted by dev)
""",
      );
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(probes: {"/Volumes/Work SSD": Future.value(true)}),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: DriveRootsApi.forPlatform(
          platform: PlatformOs.macos,
          processRunner: processRunner,
        ),
      );

      expect(await repo.listDriveRoots(), ["/Volumes/Work SSD"]);
      expect(processRunner.executable, "/sbin/mount");
    });

    test("listDriveRoots is empty when the mount table cannot be read", () async {
      final repo = FilesystemRepository(
        filesystemApi: _DriveFilesystemApi(probes: const {}),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: DriveRootsApi.forPlatform(
          platform: PlatformOs.macos,
          processRunner: RecordingProcessRunner(exitCode: 1, stderr: "mount: failed"),
        ),
      );

      expect(await repo.listDriveRoots(), isEmpty);
    });

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

    test("classifyPath follows a link to a folder", () {
      final folder = Directory("${tempDir.path}/folder")..createSync();
      final file = File("${tempDir.path}/a.txt")..createSync();
      Link("${tempDir.path}/folder-link").createSync(folder.path);
      Link("${tempDir.path}/file-link").createSync(file.path);
      Link("${tempDir.path}/dangling-link").createSync("${tempDir.path}/none");

      expect(repository.classifyPath(path: "${tempDir.path}/folder-link"), FilesystemEntityKind.directory);
      expect(repository.classifyPath(path: "${tempDir.path}/file-link"), FilesystemEntityKind.notDirectory);
      expect(repository.classifyPath(path: "${tempDir.path}/dangling-link"), FilesystemEntityKind.notDirectory);
    }, testOn: "!windows");

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
        driveRootsApi: windowsDriveRootsApi,
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
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(
        () => repo.classifyPath(path: "/protected"),
        throwsA(isA<FilesystemPermissionDeniedException>()),
      );
    });
  });

  group("FilesystemRepository.readPreviewFile", () {
    late Directory tempDir;
    late FilesystemRepository repository;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("fs_preview_test_");
      repository = FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    FilePreviewResponse preview(String name) => repository.readPreviewFile(absolutePath: "${tempDir.path}/$name");

    test("returns UTF-8 text", () {
      File("${tempDir.path}/notes.md").writeAsStringSync("# Héllo\n");

      expect(preview("notes.md"), const FilePreviewResponse.text(content: "# Héllo\n"));
    });

    test("returns text at exactly the cap and refuses one byte more", () {
      File("${tempDir.path}/fits.txt").writeAsBytesSync(List.filled(maxFilePreviewTextBytes, 0x61));
      File("${tempDir.path}/over.txt").writeAsBytesSync(List.filled(maxFilePreviewTextBytes + 1, 0x61));

      expect(preview("fits.txt"), isA<FilePreviewText>());
      expect(preview("over.txt"), const FilePreviewResponse.tooLarge());
    });

    test("returns a known image as base64 with its MIME type", () {
      final bytes = [0x89, 0x50, 0x4E, 0x47, 0x00, 0x01];
      File("${tempDir.path}/shot.PNG").writeAsBytesSync(bytes);

      expect(
        preview("shot.PNG"),
        FilePreviewResponse.image(mime: "image/png", base64: base64Encode(bytes), byteLength: bytes.length),
      );
    });

    test("refuses an image over the transcript image cap", () {
      final oversizedRepository = FilesystemRepository(
        filesystemApi: _PrefixFilesystemApi(bytes: List.filled(maxTranscriptImageBytes + 1, 0), error: null),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(oversizedRepository.readPreviewFile(absolutePath: "/big.jpg"), const FilePreviewResponse.tooLarge());
    });

    test("reports a missing file", () {
      expect(preview("absent.txt"), const FilePreviewResponse.missing());
    });

    test("reports a file in a missing folder as missing", () {
      final windowsRepository = FilesystemRepository(
        filesystemApi: _LookupFilesystemApi(
          type: FileSystemEntityType.notFound,
          resolveError: const PathNotFoundException(
            r"C:\absent\a.txt",
            OSError("The system cannot find the path specified.", 3),
          ),
        ),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(preview("absent-folder/a.txt"), const FilePreviewResponse.missing());
      expect(windowsRepository.readPreviewFile(absolutePath: r"C:\absent\a.txt"), const FilePreviewResponse.missing());
    });

    test("reports a link whose target is missing as missing", () {
      Link("${tempDir.path}/dangling.txt").createSync("${tempDir.path}/absent.txt");

      expect(preview("dangling.txt"), const FilePreviewResponse.missing());
    });

    test("refuses other binary extensions, NUL bytes, invalid UTF-8 and directories", () {
      File("${tempDir.path}/archive.zip").writeAsStringSync("plain");
      File("${tempDir.path}/nul.txt").writeAsBytesSync([0x61, 0x00, 0x62]);
      File("${tempDir.path}/latin1.txt").writeAsBytesSync([0x61, 0xE9, 0x62]);
      Directory("${tempDir.path}/folder").createSync();
      Link("${tempDir.path}/folder-link").createSync("${tempDir.path}/folder");

      for (final name in ["archive.zip", "nul.txt", "latin1.txt", "folder", "folder-link"]) {
        expect(preview(name), const FilePreviewResponse.unsupported(), reason: name);
      }
    });

    test("follows a link to a file outside its folder", () {
      final outside = Directory.systemTemp.createTempSync("fs_preview_outside_");
      addTearDown(() => outside.deleteSync(recursive: true));
      File("${outside.path}/target.txt").writeAsStringSync("linked");
      Link("${tempDir.path}/link.txt").createSync("${outside.path}/target.txt");

      expect(preview("link.txt"), const FilePreviewResponse.text(content: "linked"));
    });

    test("reports a permission denial as denied", () {
      final deniedRepository = FilesystemRepository(
        filesystemApi: _PrefixFilesystemApi(
          bytes: const [],
          error: const FileSystemException("denied", "/secret.txt", OSError("Permission denied", 13)),
        ),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(deniedRepository.readPreviewFile(absolutePath: "/secret.txt"), const FilePreviewResponse.denied());
    });

    test("reports a denied lookup as denied rather than missing", () {
      final deniedRepository = FilesystemRepository(
        filesystemApi: _LookupFilesystemApi(
          type: FileSystemEntityType.notFound,
          resolveError: const FileSystemException("denied", "/locked/a.txt", OSError("Permission denied", 13)),
        ),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(deniedRepository.readPreviewFile(absolutePath: "/locked/a.txt"), const FilePreviewResponse.denied());
    });

    test("refuses pipes and sockets without opening them", () {
      for (final type in [FileSystemEntityType.pipe, FileSystemEntityType.unixDomainSock]) {
        final repository = FilesystemRepository(
          filesystemApi: _LookupFilesystemApi(type: type, resolveError: null),
          permissionValidator: const FilesystemPermissionValidator(),
          driveRootsApi: windowsDriveRootsApi,
        );

        expect(repository.readPreviewFile(absolutePath: "/run/a.txt"), const FilePreviewResponse.unsupported());
      }
    });

    test(
      "never opens a FIFO, a link to one, or a device",
      () {
        Process.runSync("mkfifo", ["${tempDir.path}/queue.txt"]);
        Link("${tempDir.path}/queue-link.txt").createSync("${tempDir.path}/queue.txt");

        expect(preview("queue.txt"), const FilePreviewResponse.unsupported());
        expect(preview("queue-link.txt"), const FilePreviewResponse.unsupported());
        expect(repository.readPreviewFile(absolutePath: "/dev/null"), isNot(isA<FilePreviewText>()));
      },
      testOn: "!windows",
    );

    test("rethrows other filesystem failures", () {
      final failingRepository = FilesystemRepository(
        filesystemApi: _PrefixFilesystemApi(
          bytes: const [],
          error: const FileSystemException("read failed", "/broken.txt", OSError("Input/output error", 5)),
        ),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      );

      expect(
        () => failingRepository.readPreviewFile(absolutePath: "/broken.txt"),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}

/// Fake that reports a plain file and returns [bytes] or throws [error] when read.
class _PrefixFilesystemApi({required final List<int> bytes, required final FileSystemException? error})
    implements FilesystemApi {
  @override
  FileSystemEntityType entityType(String path) => FileSystemEntityType.file;

  @override
  List<int> readFilePrefix({required String path, required int maxBytes}) {
    final failure = error;
    if (failure != null) throw failure;
    return bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake that reports [type] for every path, throws [resolveError] when
/// resolving, and fails the test if anything is opened.
class _LookupFilesystemApi({required final FileSystemEntityType type, required final FileSystemException? resolveError})
    implements FilesystemApi {
  @override
  FileSystemEntityType entityType(String path) => type;

  @override
  String resolveFilePath(String path) {
    final failure = resolveError;
    if (failure != null) throw failure;
    return path;
  }

  @override
  List<int> readFilePrefix({required String path, required int maxBytes}) => fail("opened $path");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake that reports the directory exists but raises an EACCES on listing.
class _PermissionDeniedFilesystemApi() implements FilesystemApi {
  @override
  String currentDirectoryPath() => "/";

  @override
  void deleteDirectoryRecursively(String path) {}

  @override
  Future<void> deleteDirectoryRecursivelyAsync({required String path}) => throw UnimplementedError();

  @override
  Future<void> createDirectoryRecursively({required String path}) => throw UnimplementedError();

  @override
  Future<String> createTemporaryDirectory({required String parent, required String prefix}) =>
      throw UnimplementedError();

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
  Future<bool> directoryExistsAsync(String path) async => true;

  @override
  List<String> listEntryNames(String path) => throw UnimplementedError();

  @override
  Future<List<String>> listEntryNamesBounded({required String path, required int maximumEntries}) =>
      throw UnimplementedError();

  @override
  List<int> readFilePrefix({required String path, required int maxBytes}) => throw UnimplementedError();

  @override
  String resolveDirectoryPath(String path) => throw UnimplementedError();

  @override
  String resolveFilePath(String path) => throw UnimplementedError();
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

class _DriveFilesystemApi({required final Map<String, Future<bool>> _probes}) implements FilesystemApi {
  @override
  Future<bool> directoryExistsAsync(String path) => _probes[path] ?? Future.value(false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

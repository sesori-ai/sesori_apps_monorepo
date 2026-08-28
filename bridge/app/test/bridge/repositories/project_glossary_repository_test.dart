import "dart:io" show FileSystemEntityType, ProcessException;

import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:sesori_bridge/src/repositories/project_glossary_repository.dart";
import "package:test/test.dart";

void main() {
  test("loads bounded current metadata and excludes generated or vendored paths", () async {
    final gitCliApi = _SourceGitCliApi(
      trackedPaths: const [
        "pubspec.yaml",
        "README.md",
        "lib/src/XChaCha20Cipher.dart",
        "node_modules/private/SecretSdk.dart",
        "lib/src/generated_model.freezed.dart",
      ],
    );
    final filesystemApi = _SourceFilesystemApi(
      files: const {
        "/project/README.md": "# Current Worktree Quasar",
        "/project/pubspec.yaml": "name: current_acme_quasar",
      },
    );
    final repository = ProjectGlossaryRepository(
      gitCliApi: gitCliApi,
      filesystemApi: filesystemApi,
    );

    final source = await repository.loadSource(projectPath: "/project");

    expect(source.projectName, "project");
    expect(source.repositoryName, "sesori_apps_monorepo");
    expect(source.trackedPaths, [
      "README.md",
      "lib/src/XChaCha20Cipher.dart",
      "pubspec.yaml",
    ]);
    expect(source.metadataDocuments, ["# Current Worktree Quasar", "name: current_acme_quasar"]);
    expect(gitCliApi.requestedMaximumPaths, 50000);
    expect(filesystemApi.requestedMaximumBytes, everyElement(32 * 1024));
  });

  test("does not scan untracked root metadata in a Git project", () async {
    final filesystemApi = _SourceFilesystemApi(
      files: const {
        "/project/README.md": "untracked local vocabulary",
        "/project/package.json": "untracked-local-package",
      },
      rootEntries: const ["README.md", "package.json"],
    );
    final repository = ProjectGlossaryRepository(
      gitCliApi: _SourceGitCliApi(trackedPaths: const ["lib/App.dart"]),
      filesystemApi: filesystemApi,
    );

    final source = await repository.loadSource(projectPath: "/project");

    expect(source.trackedPaths, ["lib/App.dart"]);
    expect(source.metadataDocuments, isEmpty);
    expect(filesystemApi.requestedMaximumEntries, isNull);
  });

  test("uses only a bounded root listing for a non-Git project", () async {
    final filesystemApi = _SourceFilesystemApi(
      files: const {"/project/README.md": "# Local Quasar"},
      rootEntries: const ["README.md", "build", "vendor", "LocalCompiler.dart"],
    );
    final gitCliApi = _SourceGitCliApi(isGitProject: false);
    final repository = ProjectGlossaryRepository(
      gitCliApi: gitCliApi,
      filesystemApi: filesystemApi,
    );

    final source = await repository.loadSource(projectPath: "/project");

    expect(source.repositoryName, isNull);
    expect(source.trackedPaths, ["LocalCompiler.dart", "README.md"]);
    expect(source.metadataDocuments, ["# Local Quasar"]);
    expect(filesystemApi.requestedMaximumEntries, 50000);
    expect(gitCliApi.remoteReadCount, 0);
    expect(gitCliApi.trackedReadCount, 0);
  });

  test("preserves operational Git membership failures", () async {
    final repository = ProjectGlossaryRepository(
      gitCliApi: _SourceGitCliApi(
        membershipError: const ProcessException(
          "git",
          ["rev-parse"],
          "fatal: detected dubious ownership",
          128,
        ),
      ),
      filesystemApi: _SourceFilesystemApi(files: const {}),
    );

    await expectLater(
      repository.loadSource(projectPath: "/project"),
      throwsA(isA<ProcessException>()),
    );
  });

  test("preserves operational remote and tracked-file failures", () async {
    for (final gitCliApi in [
      _SourceGitCliApi(
        remoteError: const ProcessException("git", ["remote"], "temporary failure", 1),
      ),
      _SourceGitCliApi(
        trackedError: const ProcessException("git", ["ls-files"], "temporary failure", 1),
      ),
    ]) {
      final repository = ProjectGlossaryRepository(
        gitCliApi: gitCliApi,
        filesystemApi: _SourceFilesystemApi(files: const {}),
      );

      await expectLater(
        repository.loadSource(projectPath: "/project"),
        throwsA(isA<ProcessException>()),
      );
    }
  });
}

class _SourceGitCliApi({
  final bool isGitProject = true,
  final List<String> trackedPaths = const [],
  final Object? membershipError,
  final Object? remoteError,
  final Object? trackedError,
}) extends GitCliApi {
  this
    : super(
        processRunner: ProcessRunner(),
        streamingProcessRunner: const StreamingProcessRunner(),
        gitPathExists: ({required String gitPath}) => true,
      );

  int? requestedMaximumPaths;
  int remoteReadCount = 0;
  int trackedReadCount = 0;

  @override
  Future<bool> isInsideGitWorkTree({required String projectPath}) async {
    if (membershipError case final error?) throw error;
    return isGitProject;
  }

  @override
  Future<String?> getRemoteUrl({required String projectPath}) async {
    remoteReadCount++;
    if (remoteError case final error?) throw error;
    return "git@github.com:sesori-ai/sesori_apps_monorepo.git";
  }

  @override
  Future<List<String>> listTrackedFiles({required String projectPath, required int maximumPaths}) async {
    trackedReadCount++;
    requestedMaximumPaths = maximumPaths;
    if (trackedError case final error?) throw error;
    return trackedPaths.take(maximumPaths).toList(growable: false);
  }
}

class _SourceFilesystemApi({
  required final Map<String, String> files,
  final List<String>? rootEntries,
}) extends FilesystemApi {
  int? requestedMaximumEntries;
  final List<int> requestedMaximumBytes = [];

  @override
  Future<List<String>> listEntryNamesBounded({required String path, required int maximumEntries}) async {
    requestedMaximumEntries = maximumEntries;
    return (rootEntries ?? const []).take(maximumEntries).toList(growable: false);
  }

  @override
  FileSystemEntityType entityType(String path) =>
      files.containsKey(path) ? FileSystemEntityType.file : FileSystemEntityType.notFound;

  @override
  List<int> readFilePrefix({required String path, required int maxBytes}) {
    requestedMaximumBytes.add(maxBytes);
    return files[path]!.codeUnits.take(maxBytes + 1).toList(growable: false);
  }
}

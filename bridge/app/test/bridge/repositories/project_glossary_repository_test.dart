import "dart:async";
import "dart:io" show FileSystemEntityType, ProcessException;

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/api/git_cli_api.dart";
import "package:sesori_bridge/src/api/models/project_glossary_response.dart";
import "package:sesori_bridge/src/api/sesori_server_api.dart";
import "package:sesori_bridge/src/foundation/abortable_request.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/repositories/project_glossary_repository.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  test("loads only bounded high-signal metadata and excludes generated or vendored paths", () async {
    final gitCliApi = _SourceGitCliApi(
      trackedPaths: const [
        "README.md",
        "pubspec.yaml",
        "lib/src/XChaCha20Cipher.dart",
        "node_modules/private/SecretSdk.dart",
        "lib/src/generated_model.freezed.dart",
      ],
    );
    final repository = ProjectGlossaryRepository(
      gitCliApi: gitCliApi,
      filesystemApi: const _SourceFilesystemApi(
        files: {
          "/project/README.md": "# Acme Quasar",
          "/project/pubspec.yaml": "name: acme_quasar",
        },
      ),
      serverApi: SesoriServerApi(
        authBackendUrl: "https://unused.example.test",
        client: MockClient((_) async => throw StateError("network must not be called")),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: FakeTokenRefresher(token: "unused"),
      ),
    );

    final source = await repository.loadSource(projectPath: "/project");

    expect(source.projectName, "project");
    expect(source.repositoryName, "sesori_apps_monorepo");
    expect(source.trackedPaths, [
      "README.md",
      "pubspec.yaml",
      "lib/src/XChaCha20Cipher.dart",
    ]);
    expect(source.metadataDocuments, ["# Acme Quasar", "name: acme_quasar"]);
    expect(gitCliApi.requestedMaximumPaths, 50000);
  });

  test("translates HTTP aborts at the repository boundary", () async {
    final abort = http.RequestAbortedException(Uri.parse("https://auth.example.test/voice/glossary"));
    final repository = ProjectGlossaryRepository(
      gitCliApi: _SourceGitCliApi(),
      filesystemApi: const _SourceFilesystemApi(files: {}),
      serverApi: _AbortingSesoriServerApi(abort),
    );

    await expectLater(
      repository.getWords(projectKey: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
      throwsA(
        isA<ProjectGlossaryRepositoryAbortedException>().having(
          (error) => error.innerError,
          "innerError",
          same(abort),
        ),
      ),
    );
  });

  test("owns and aborts the HTTP lifecycle signal during shutdown", () async {
    final serverApi = _PendingSesoriServerApi();
    final repository = ProjectGlossaryRepository(
      gitCliApi: _SourceGitCliApi(),
      filesystemApi: const _SourceFilesystemApi(files: {}),
      serverApi: serverApi,
    );

    final request = repository.getWords(projectKey: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
    await serverApi.requestStarted.future;
    repository.beginShutdown();

    expect(serverApi.abortSignal?.isAborted, isTrue);
    serverApi.response.complete(const ProjectGlossaryWordsResponse(words: []));
    expect(await request, isEmpty);
  });

  test("preserves operational Git failures instead of scanning as non-Git", () async {
    final repository = ProjectGlossaryRepository(
      gitCliApi: _FailingMembershipGitCliApi(),
      filesystemApi: const _SourceFilesystemApi(files: {}),
      serverApi: SesoriServerApi(
        authBackendUrl: "https://unused.example.test",
        client: MockClient((_) async => throw StateError("network must not be called")),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: FakeTokenRefresher(token: "unused"),
      ),
    );

    await expectLater(
      repository.loadSource(projectPath: "/project"),
      throwsA(isA<ProcessException>()),
    );
  });

  test("does not scan untracked or ignored root metadata in a Git project", () async {
    final repository = ProjectGlossaryRepository(
      gitCliApi: _SourceGitCliApi(trackedPaths: const ["lib/App.dart"]),
      filesystemApi: const _SourceFilesystemApi(
        files: {
          "/project/README.md": "private local vocabulary",
          "/project/package.json": "private-local-package",
        },
      ),
      serverApi: SesoriServerApi(
        authBackendUrl: "https://unused.example.test",
        client: MockClient((_) async => throw StateError("network must not be called")),
        requestDeadline: const Duration(seconds: 1),
        tokenRefresher: FakeTokenRefresher(token: "unused"),
      ),
    );

    final source = await repository.loadSource(projectPath: "/project");

    expect(source.trackedPaths, ["lib/App.dart"]);
    expect(source.metadataDocuments, isEmpty);
  });
}

class _AbortingSesoriServerApi(final Object failure) implements SesoriServerApi {
  @override
  Future<ProjectGlossaryWordsResponse> getProjectGlossary({
    required String projectKey,
    required AbortSignal abortSignal,
  }) => Future<ProjectGlossaryWordsResponse>.error(failure);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingSesoriServerApi() implements SesoriServerApi {
  final Completer<void> requestStarted = Completer<void>();
  final Completer<ProjectGlossaryWordsResponse> response = Completer<ProjectGlossaryWordsResponse>();
  AbortSignal? abortSignal;

  @override
  Future<ProjectGlossaryWordsResponse> getProjectGlossary({
    required String projectKey,
    required AbortSignal abortSignal,
  }) {
    this.abortSignal = abortSignal;
    requestStarted.complete();
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SourceGitCliApi({final List<String> trackedPaths = const []}) extends GitCliApi {
  this
    : super(
        processRunner: ProcessRunner(),
        gitPathExists: ({required String gitPath}) => true,
      );

  int? requestedMaximumPaths;

  @override
  Future<bool> isInsideGitWorkTree({required String projectPath}) async => true;

  @override
  Future<String?> getRemoteUrl({required String projectPath}) async =>
      "git@github.com:sesori-ai/sesori_apps_monorepo.git";

  @override
  Future<List<String>> listTrackedFiles({required String projectPath, required int maximumPaths}) async {
    requestedMaximumPaths = maximumPaths;
    return trackedPaths.take(maximumPaths).toList(growable: false);
  }
}

class _FailingMembershipGitCliApi() extends _SourceGitCliApi {
  @override
  Future<bool> isInsideGitWorkTree({required String projectPath}) async {
    throw const ProcessException("git", ["rev-parse"], "fatal: detected dubious ownership", 128);
  }
}

class const _SourceFilesystemApi({
  required final Map<String, String> files,
}) extends FilesystemApi {
  @override
  Future<List<String>> listEntryNamesBounded({required String path, required int maximumEntries}) {
    throw StateError("Git projects must not enumerate root entries");
  }

  @override
  FileSystemEntityType entityType(String path) =>
      files.containsKey(path) ? FileSystemEntityType.file : FileSystemEntityType.notFound;

  @override
  List<int> readFilePrefix({required String path, required int maxBytes}) => files[path]!.codeUnits;
}

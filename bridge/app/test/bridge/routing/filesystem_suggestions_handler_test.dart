import "dart:io";

import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/routing/filesystem_suggestions_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("FilesystemSuggestionsHandler", () {
    late FilesystemSuggestionsHandler handler;
    late Directory tempDir;

    setUp(() {
      handler = FilesystemSuggestionsHandler(
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      );
      tempDir = Directory.systemTemp.createTempSync("sesori_test_");
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test("canHandle POST /filesystem/suggestions", () {
      expect(
        handler.canHandle(makeRequest("POST", "/filesystem/suggestions")),
        isTrue,
      );
    });

    test("does not handle GET /filesystem/suggestions", () {
      expect(
        handler.canHandle(makeRequest("GET", "/filesystem/suggestions")),
        isFalse,
      );
    });

    test("returns typed directories for valid prefix", () async {
      Directory("${tempDir.path}/project1").createSync();
      final result = await handler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: FilesystemSuggestionsRequest(maxResults: 20, prefix: tempDir.path),
      );
      expect(result.data, hasLength(1));
      final entry = result.data.first;
      expect(entry.path, equals("${tempDir.path}/project1"));
      expect(entry.name, equals("project1"));
      expect(entry.isGitRepo, isFalse);
    });

    test("throws 404 for non-existent prefix path", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/filesystem/suggestions"),
          body: const FilesystemSuggestionsRequest(
            maxResults: 20,
            prefix: "/nonexistent/path/that/does/not/exist",
          ),
        ),
        throwsA(
          isA<RelayResponse>().having((r) => r.status, "status", equals(404)),
        ),
      );
    });

    test("returns home directory children when prefix is missing", () async {
      final result = await handler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: const FilesystemSuggestionsRequest(maxResults: 20, prefix: null),
      );
      expect(result.data, isNotEmpty);
      for (final entry in result.data) {
        expect(entry.path, isNotEmpty);
        expect(entry.name, isNotEmpty);
      }
    });

    test("adds a Windows host's drives only to a request without a prefix", () async {
      final windowsHandler = FilesystemSuggestionsHandler(
        filesystemRepository: FilesystemRepository(
          filesystemApi: _WindowsFilesystemApi(home: tempDir.path),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      );

      final opening = await windowsHandler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: const FilesystemSuggestionsRequest(maxResults: 20, prefix: null),
      );
      final browsing = await windowsHandler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: FilesystemSuggestionsRequest(maxResults: 20, prefix: tempDir.path),
      );

      expect(opening.path, tempDir.path);
      expect(opening.driveRoots, [r"C:\", r"D:\"]);
      expect(browsing.driveRoots, isEmpty);
    });

    test("delegates the request's prefix and limit to the repository", () async {
      final repository = _RecordingFilesystemRepository();
      final delegatingHandler = FilesystemSuggestionsHandler(filesystemRepository: repository);

      final opening = await delegatingHandler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: const FilesystemSuggestionsRequest(maxResults: 7, prefix: null),
      );
      await delegatingHandler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: FilesystemSuggestionsRequest(maxResults: 9, prefix: tempDir.path),
      );

      expect(opening, same(repository.result));
      expect(repository.calls, [(prefix: null, maxResults: 7), (prefix: tempDir.path, maxResults: 9)]);
    });

    test("throws 400 for path traversal attempt with ../", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/filesystem/suggestions"),
          body: const FilesystemSuggestionsRequest(maxResults: 20, prefix: "/some/../etc/passwd"),
        ),
        throwsA(
          isA<RelayResponse>().having((r) => r.status, "status", equals(400)),
        ),
      );
    });

    test("throws 400 for relative path", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/filesystem/suggestions"),
          body: const FilesystemSuggestionsRequest(maxResults: 20, prefix: "relative/path"),
        ),
        throwsA(
          isA<RelayResponse>().having((r) => r.status, "status", equals(400)),
        ),
      );
    });

    test("throws 400 for empty prefix", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/filesystem/suggestions"),
          body: const FilesystemSuggestionsRequest(maxResults: 20, prefix: ""),
        ),
        throwsA(
          isA<RelayResponse>().having((r) => r.status, "status", equals(400)),
        ),
      );
    });

    test("caps results at 20 entries maximum", () async {
      for (var i = 0; i < 25; i++) {
        Directory("${tempDir.path}/project_${i.toString().padLeft(2, "0")}").createSync();
      }
      final result = await handler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: FilesystemSuggestionsRequest(maxResults: 20, prefix: tempDir.path),
      );
      expect(result.data.length, lessThanOrEqualTo(20));
    });

    test("returns only directories, not files", () async {
      Directory("${tempDir.path}/subdir").createSync();
      File("${tempDir.path}/file.txt").writeAsStringSync("content");
      final result = await handler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: FilesystemSuggestionsRequest(maxResults: 20, prefix: tempDir.path),
      );
      expect(result.data, hasLength(1));
      expect(result.data.first.name, equals("subdir"));
    });

    test("entry has isGitRepo true when .git subdirectory exists", () async {
      final projectDir = Directory("${tempDir.path}/my_repo")..createSync();
      Directory("${projectDir.path}/.git").createSync();
      final result = await handler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: FilesystemSuggestionsRequest(maxResults: 20, prefix: tempDir.path),
      );
      expect(result.data, hasLength(1));
      expect(result.data.first.isGitRepo, isTrue);
    });

    test("excludes hidden directories from results", () async {
      Directory("${tempDir.path}/visible").createSync();
      Directory("${tempDir.path}/.hidden").createSync();
      final result = await handler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: FilesystemSuggestionsRequest(maxResults: 20, prefix: tempDir.path),
      );
      expect(result.data, hasLength(1));
      expect(result.data.first.name, equals("visible"));
    });
  });
}

/// The real filesystem, reporting a Windows host with drives C and D and
/// [home] as the user's home folder.
class _WindowsFilesystemApi({required final String home}) extends FilesystemApi {
  @override
  bool get isWindows => true;

  @override
  Map<String, String> get environment => {"HOME": home, "USERPROFILE": home};

  @override
  Future<bool> directoryExistsAsync(String path) async => path == r"C:\" || path == r"D:\";
}

/// Records each browser listing request and answers with [result].
class _RecordingFilesystemRepository() implements FilesystemRepository {
  final calls = <({String? prefix, int maxResults})>[];
  final result = const FilesystemSuggestions(data: [], path: "/home/dev", driveRoots: [r"C:\"]);

  @override
  Future<FilesystemSuggestions> listBrowserSuggestions({required String? prefix, required int maxResults}) async {
    calls.add((prefix: prefix, maxResults: maxResults));
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

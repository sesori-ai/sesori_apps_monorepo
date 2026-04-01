import "dart:io";

import "package:sesori_bridge/src/bridge/routing/filesystem_suggestions_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("FilesystemSuggestionsHandler", () {
    late FilesystemSuggestionsHandler handler;
    late Directory tempDir;

    setUp(() {
      handler = FilesystemSuggestionsHandler();
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
        pathParams: {},
        queryParams: {},
        fragment: null,
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
          pathParams: {},
          queryParams: {},
          fragment: null,
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
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(result.data, isNotEmpty);
      for (final entry in result.data) {
        expect(entry.path, isNotEmpty);
        expect(entry.name, isNotEmpty);
      }
    });

    test("throws 400 for path traversal attempt with ../", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/filesystem/suggestions"),
          body: const FilesystemSuggestionsRequest(maxResults: 20, prefix: "/some/../etc/passwd"),
          pathParams: {},
          queryParams: {},
          fragment: null,
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
          pathParams: {},
          queryParams: {},
          fragment: null,
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
          pathParams: {},
          queryParams: {},
          fragment: null,
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
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(result.data.length, lessThanOrEqualTo(20));
    });

    test("returns only directories, not files", () async {
      Directory("${tempDir.path}/subdir").createSync();
      File("${tempDir.path}/file.txt").writeAsStringSync("content");
      final result = await handler.handle(
        makeRequest("POST", "/filesystem/suggestions"),
        body: FilesystemSuggestionsRequest(maxResults: 20, prefix: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
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
        pathParams: {},
        queryParams: {},
        fragment: null,
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
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(result.data, hasLength(1));
      expect(result.data.first.name, equals("visible"));
    });
  });
}

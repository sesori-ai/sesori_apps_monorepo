import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/routing/filesystem_suggestions_handler.dart";
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

    // Test 1: valid prefix path returns JSON array with correct fields
    test("returns 200 with wrapped JSON directories for valid prefix", () async {
      Directory("${tempDir.path}/project1").createSync();
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final data = body["data"] as List<dynamic>;
      expect(data, hasLength(1));
      final entry = data[0] as Map<String, dynamic>;
      expect(entry["path"], equals("${tempDir.path}/project1"));
      expect(entry["name"], equals("project1"));
      expect(entry["isGitRepo"], isFalse);
    });

    // Test 2: non-existent prefix path returns 404
    test("returns 404 for non-existent prefix path", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": "/nonexistent/path/that/does/not/exist"}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(404));
      expect(response.body, contains("directory not found"));
    });

    // Test 3: missing prefix returns home directory children
    test("returns home directory children when prefix is missing", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": null}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final data = body["data"] as List<dynamic>;
      // Home directory should have at least some child directories
      expect(data, isNotEmpty);
      // Every entry must have the required fields
      for (final entry in data) {
        final map = entry as Map<String, dynamic>;
        expect(map.containsKey("path"), isTrue);
        expect(map.containsKey("name"), isTrue);
        expect(map.containsKey("isGitRepo"), isTrue);
      }
    });

    // Test 4: path traversal attempt returns 400
    test("returns 400 for path traversal attempt with ../", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": "/some/../etc/passwd"}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(400));
    });

    // Test 5: relative path returns 400
    test("returns 400 for relative path", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": "relative/path"}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(400));
    });

    // Test 6: empty prefix returns 400
    test("returns 400 for empty prefix", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": ""}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(400));
    });

    // Test 7: results are capped at 20 entries
    test("caps results at 20 entries maximum", () async {
      for (var i = 0; i < 25; i++) {
        Directory("${tempDir.path}/project_${i.toString().padLeft(2, "0")}").createSync();
      }
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final data = body["data"] as List<dynamic>;
      expect(data.length, lessThanOrEqualTo(20));
    });

    // Test 8: only directories returned, files excluded
    test("returns only directories, not files", () async {
      Directory("${tempDir.path}/subdir").createSync();
      File("${tempDir.path}/file.txt").writeAsStringSync("content");
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final data = body["data"] as List<dynamic>;
      expect(data, hasLength(1));
      expect((data[0] as Map<String, dynamic>)["name"], equals("subdir"));
    });

    // Test 9: entry with .git subdirectory has isGitRepo: true
    test("entry has isGitRepo true when .git subdirectory exists", () async {
      final projectDir = Directory("${tempDir.path}/my_repo")..createSync();
      Directory("${projectDir.path}/.git").createSync();
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final data = body["data"] as List<dynamic>;
      expect(data, hasLength(1));
      expect((data[0] as Map<String, dynamic>)["isGitRepo"], isTrue);
    });

    // Test 10: hidden directories (starting with .) are excluded
    test("excludes hidden directories from results", () async {
      Directory("${tempDir.path}/visible").createSync();
      Directory("${tempDir.path}/.hidden").createSync();
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/filesystem/suggestions",
          body: jsonEncode({"maxResults": 20, "prefix": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final data = body["data"] as List<dynamic>;
      expect(data, hasLength(1));
      expect((data[0] as Map<String, dynamic>)["name"], equals("visible"));
    });
  });
}

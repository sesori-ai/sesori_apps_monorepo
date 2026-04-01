import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ProjectPathRequest", () {
    test("JSON roundtrip with valid path", () {
      const original = ProjectPathRequest(path: "/Users/dev/my-project");
      final json = original.toJson();
      final restored = ProjectPathRequest.fromJson(json);

      expect(restored, equals(original));
      expect(json, equals({"path": "/Users/dev/my-project"}));
    });

    test("fromJson throws on missing required field", () {
      expect(
        () => ProjectPathRequest.fromJson({}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group("DiscoverProjectRequest", () {
    test("JSON roundtrip with valid path", () {
      const original = DiscoverProjectRequest(path: "/Users/dev/existing");
      final json = original.toJson();
      final restored = DiscoverProjectRequest.fromJson(json);

      expect(restored, equals(original));
      expect(json, equals({"path": "/Users/dev/existing"}));
    });

    test("fromJson throws on missing required field", () {
      expect(
        () => DiscoverProjectRequest.fromJson({}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group("FilesystemSuggestion", () {
    test("JSON roundtrip with all fields", () {
      const original = FilesystemSuggestion(
        path: "/Users/dev/foo",
        name: "foo",
        isGitRepo: true,
      );
      final json = original.toJson();
      final restored = FilesystemSuggestion.fromJson(json);

      expect(restored, equals(original));
      expect(
        json,
        equals({
          "path": "/Users/dev/foo",
          "name": "foo",
          "isGitRepo": true,
        }),
      );
    });

    test("JSON roundtrip with isGitRepo false", () {
      const original = FilesystemSuggestion(
        path: "/Users/dev/bar",
        name: "bar",
        isGitRepo: false,
      );
      final json = original.toJson();
      final restored = FilesystemSuggestion.fromJson(json);

      expect(restored, equals(original));
      expect(
        json,
        equals({
          "path": "/Users/dev/bar",
          "name": "bar",
          "isGitRepo": false,
        }),
      );
    });

    test("fromJson throws on missing path", () {
      expect(
        () => FilesystemSuggestion.fromJson({
          "name": "foo",
          "isGitRepo": true,
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test("fromJson throws on missing name", () {
      expect(
        () => FilesystemSuggestion.fromJson({
          "path": "/Users/dev/foo",
          "isGitRepo": true,
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test("fromJson throws on missing isGitRepo", () {
      expect(
        () => FilesystemSuggestion.fromJson({
          "path": "/Users/dev/foo",
          "name": "foo",
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}

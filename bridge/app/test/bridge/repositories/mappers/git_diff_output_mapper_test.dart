import "package:sesori_bridge/src/bridge/repositories/mappers/git_diff_output_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const mapper = GitDiffOutputMapper();

  group("parseUntrackedPaths", () {
    test("parses one path per line and ignores blanks", () {
      expect(
        mapper.parseUntrackedPaths(output: "lib/new.dart\nassets/icon.png\n\n"),
        equals(["lib/new.dart", "assets/icon.png"]),
      );
    });

    test("preserves leading and trailing whitespace in filenames", () {
      expect(
        mapper.parseUntrackedPaths(output: " lib/spaced.dart \n"),
        equals([" lib/spaced.dart "]),
      );
    });

    test("strips carriage return line endings only", () {
      expect(
        mapper.parseUntrackedPaths(output: "lib/new.dart\r\n"),
        equals(["lib/new.dart"]),
      );
    });
  });

  group("mergeTrackedAndUntrackedEntries", () {
    test("appends untracked paths without duplicating tracked files", () {
      final merged = mapper.mergeTrackedAndUntrackedEntries(
        trackedEntries: [
          (file: "lib/modified.dart", status: FileDiffStatus.modified),
        ],
        untrackedPaths: ["lib/modified.dart", "lib/new.dart"],
      );

      expect(merged, hasLength(2));
      expect(merged[0].file, equals("lib/modified.dart"));
      expect(merged[1], equals((file: "lib/new.dart", status: FileDiffStatus.added)));
    });

    test("promotes deleted tracked files to modified when untracked replacement exists", () {
      final merged = mapper.mergeTrackedAndUntrackedEntries(
        trackedEntries: [
          (file: "lib/replaced.dart", status: FileDiffStatus.deleted),
        ],
        untrackedPaths: ["lib/replaced.dart"],
      );

      expect(merged, hasLength(1));
      expect(merged.single, equals((file: "lib/replaced.dart", status: FileDiffStatus.modified)));
    });
  });
}

import "package:sesori_bridge/src/bridge/repositories/mappers/git_diff_output_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const mapper = GitDiffOutputMapper();

  group("parseUntrackedPaths", () {
    test("parses NUL-delimited raw paths", () {
      expect(
        mapper.parseUntrackedPaths(output: "lib/new.dart\x00assets/icon.png\x00"),
        equals(["lib/new.dart", "assets/icon.png"]),
      );
    });

    test("preserves leading and trailing whitespace in filenames", () {
      expect(
        mapper.parseUntrackedPaths(output: " lib/spaced.dart \x00"),
        equals([" lib/spaced.dart "]),
      );
    });

    test("preserves newlines and tabs in filenames", () {
      expect(
        mapper.parseUntrackedPaths(output: "lib/new\nfile.dart\x00lib/tab\tfile.dart\x00"),
        equals(["lib/new\nfile.dart", "lib/tab\tfile.dart"]),
      );
    });
  });

  test("parseNameStatus preserves raw NUL-delimited paths", () {
    expect(
      mapper.parseNameStatus(
        output: 'M\x00lib/quote"and\nnewline.dart\x00A\x00lib/tab\tfile.dart\x00',
      ),
      equals([
        (file: 'lib/quote"and\nnewline.dart', status: FileDiffStatus.modified),
        (file: "lib/tab\tfile.dart", status: FileDiffStatus.added),
      ]),
    );
  });

  test("parseNumstat preserves raw paths after count fields", () {
    expect(
      mapper.parseNumstat(output: "3\t2\tlib/quote\\and\nnewline.dart\x00"),
      equals({
        "lib/quote\\and\nnewline.dart": (additions: 3, deletions: 2),
      }),
    );
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

import "package:sesori_bridge/src/bridge/session_diffs/git_diff_parser.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("parseUntrackedPaths", () {
    test("parses one path per line and ignores blanks", () {
      expect(
        parseUntrackedPaths("lib/new.dart\nassets/icon.png\n\n"),
        equals(["lib/new.dart", "assets/icon.png"]),
      );
    });
  });

  group("mergeTrackedAndUntrackedEntries", () {
    test("appends untracked paths without duplicating tracked files", () {
      final merged = mergeTrackedAndUntrackedEntries(
        trackedEntries: [
          (file: "lib/modified.dart", status: FileDiffStatus.modified),
        ],
        untrackedPaths: ["lib/modified.dart", "lib/new.dart"],
      );

      expect(merged, hasLength(2));
      expect(merged[0].file, equals("lib/modified.dart"));
      expect(merged[1], equals((file: "lib/new.dart", status: FileDiffStatus.added)));
    });
  });
}

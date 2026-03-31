import "package:sesori_dart_core/src/utils/diff/diff_engine.dart";
import "package:test/test.dart";

void main() {
  group("DiffEngine.computeDiff", () {
    test("equal files", () {
      const content = "alpha\nbeta\ngamma\n";

      final result = DiffEngine.computeDiff(before: content, after: content);

      expect(result.hunks, isEmpty);
      expect(result.additions, 0);
      expect(result.deletions, 0);
    });

    test("pure addition (empty before)", () {
      const after = "a\nb\nc\n";

      final result = DiffEngine.computeDiff(before: "", after: after);

      expect(result.hunks, hasLength(1));
      expect(result.additions, 3);
      expect(result.deletions, 0);

      final lines = result.hunks.single.lines;
      expect(lines, hasLength(3));
      expect(lines.every((line) => line.type == DiffLineType.added), isTrue);
      expect(lines.every((line) => line.oldLineNumber == null), isTrue);
      expect(lines.map((line) => line.newLineNumber), [1, 2, 3]);
      expect(lines.map((line) => line.content), ["a", "b", "c"]);
    });

    test("pure deletion (empty after)", () {
      const before = "a\nb\nc\n";

      final result = DiffEngine.computeDiff(before: before, after: "");

      expect(result.hunks, hasLength(1));
      expect(result.additions, 0);
      expect(result.deletions, 3);

      final lines = result.hunks.single.lines;
      expect(lines, hasLength(3));
      expect(lines.every((line) => line.type == DiffLineType.removed), isTrue);
      expect(lines.every((line) => line.newLineNumber == null), isTrue);
      expect(lines.map((line) => line.oldLineNumber), [1, 2, 3]);
      expect(lines.map((line) => line.content), ["a", "b", "c"]);
    });

    test("single line changed", () {
      const before = "line1\nline2\nline3\n";
      const after = "line1\nline2 updated\nline3\n";

      final result = DiffEngine.computeDiff(before: before, after: after);

      expect(result.hunks, hasLength(1));
      expect(result.additions, 1);
      expect(result.deletions, 1);

      final lines = result.hunks.single.lines;
      expect(lines.map((line) => line.type), [
        DiffLineType.context,
        DiffLineType.removed,
        DiffLineType.added,
        DiffLineType.context,
      ]);
      expect(lines[1].oldLineNumber, 2);
      expect(lines[1].newLineNumber, null);
      expect(lines[2].oldLineNumber, null);
      expect(lines[2].newLineNumber, 2);
    });

    test("mixed changes", () {
      final before = "${List<String>.generate(16, (i) => "line ${i + 1}").join("\n")}\n";
      final afterLines = List<String>.generate(16, (i) => "line ${i + 1}");
      afterLines[1] = "line 2 updated";
      afterLines[12] = "line 13 updated";
      final after = "${afterLines.join("\n")}\n";

      final result = DiffEngine.computeDiff(before: before, after: after);

      expect(result.hunks, hasLength(2));
      expect(result.additions, 2);
      expect(result.deletions, 2);
      expect(result.hunks.first.lines.any((line) => line.content == "line 2 updated"), isTrue);
      expect(result.hunks.last.lines.any((line) => line.content == "line 13 updated"), isTrue);
    });

    test("context merging", () {
      final beforeLines = List<String>.generate(12, (i) => "line ${i + 1}");
      final afterLines = [...beforeLines];
      afterLines[3] = "line 4 changed";
      afterLines[8] = "line 9 changed";

      final before = "${beforeLines.join("\n")}\n";
      final after = "${afterLines.join("\n")}\n";

      final result = DiffEngine.computeDiff(before: before, after: after);

      expect(result.hunks, hasLength(1));
      expect(result.additions, 2);
      expect(result.deletions, 2);
      final contents = result.hunks.single.lines.map((line) => line.content).toList();
      expect(contents, contains("line 4 changed"));
      expect(contents, contains("line 9 changed"));
    });

    test("no trailing newline", () {
      const before = "alpha\nbeta";
      const after = "alpha\nbeta updated";

      final result = DiffEngine.computeDiff(before: before, after: after);

      expect(result.hunks, hasLength(1));
      expect(result.additions, 1);
      expect(result.deletions, 1);
      expect(result.hunks.single.lines.any((line) => line.content == "beta updated"), isTrue);
    });

    test("unicode content", () {
      const before = "hello\n😀 grin\ncafe\n";
      const after = "hello\n😀 grin\ncafe\nnaive\n";

      final result = DiffEngine.computeDiff(before: before, after: after);

      expect(result.hunks, hasLength(1));
      expect(result.additions, 1);
      expect(result.deletions, 0);
      expect(result.hunks.single.lines.last.content, "naive");
    });

    test("identical single-line files", () {
      final result = DiffEngine.computeDiff(before: "single line", after: "single line");

      expect(result.hunks, isEmpty);
      expect(result.additions, 0);
      expect(result.deletions, 0);
    });

    test("large content (100+ lines)", () {
      final beforeLines = List<String>.generate(120, (i) => "line ${i + 1}");
      final afterLines = [...beforeLines];
      afterLines[0] = "line 1 changed";
      afterLines[59] = "line 60 changed";
      afterLines[119] = "line 120 changed";

      final before = "${beforeLines.join("\n")}\n";
      final after = "${afterLines.join("\n")}\n";

      final result = DiffEngine.computeDiff(before: before, after: after);

      expect(result.additions, 3);
      expect(result.deletions, 3);

      final changedAddedLines = result.hunks
          .expand((hunk) => hunk.lines)
          .where((line) => line.type == DiffLineType.added && line.content.contains("changed"))
          .map((line) => line.newLineNumber)
          .toSet();

      expect(changedAddedLines, {1, 60, 120});
    });
  });
}

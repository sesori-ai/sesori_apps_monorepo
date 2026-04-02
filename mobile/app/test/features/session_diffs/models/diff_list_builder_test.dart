import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/utils/diff/diff_engine.dart";
import "package:sesori_mobile/features/session_diffs/models/diff_file_view_model.dart";
import "package:sesori_mobile/features/session_diffs/models/diff_list_builder.dart";
import "package:sesori_mobile/features/session_diffs/models/diff_list_item.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  DiffLineViewModel buildLine({
    required DiffLineType type,
    required String content,
    required int? oldLineNumber,
    required int? newLineNumber,
  }) {
    return DiffLineViewModel(
      line: DiffLine(
        type: type,
        oldLineNumber: oldLineNumber,
        newLineNumber: newLineNumber,
        content: content,
      ),
    );
  }

  DiffHunkViewModel buildHunk({required List<DiffLineViewModel> lines}) {
    return DiffHunkViewModel(
      hunk: DiffHunk(
        oldStart: 1,
        oldCount: 1,
        newStart: 1,
        newCount: 1,
        lines: lines.map((line) => line.line).toList(),
      ),
      lines: lines,
    );
  }

  DiffFileViewModel buildFile({
    required String file,
    required List<DiffHunkViewModel> hunks,
    required FileDiffSkipReason? skipReason,
  }) {
    return DiffFileViewModel(
      fileDiff: FileDiff.content(
        file: file,
        before: "",
        after: "",
        additions: 0,
        deletions: 0,
        status: FileDiffStatus.modified,
      ),
      fileName: file,
      hunks: hunks,
      additions: 0,
      deletions: 0,
      status: FileDiffStatus.modified,
      skipReason: skipReason,
    );
  }

  group("buildFlatList", () {
    test("empty view models returns empty list", () {
      final items = buildFlatList(viewModels: const [], expandedFileIndices: <int>{});
      expect(items, isEmpty);
    });

    test("single expanded file with one hunk and two lines", () {
      final file = buildFile(
        file: "lib/a.dart",
        hunks: [
          buildHunk(
            lines: [
              buildLine(
                type: DiffLineType.context,
                content: "line 1",
                oldLineNumber: 1,
                newLineNumber: 1,
              ),
              buildLine(
                type: DiffLineType.added,
                content: "line 2",
                oldLineNumber: null,
                newLineNumber: 2,
              ),
            ],
          ),
        ],
        skipReason: null,
      );

      final items = buildFlatList(viewModels: [file], expandedFileIndices: <int>{0});

      expect(items, hasLength(4));
      expect(items[0], isA<DiffListFileHeader>());
      expect(items[1], isA<DiffListHunkHeader>());
      expect(items[2], isA<DiffListLine>());
      expect(items[3], isA<DiffListLine>());
    });

    test("single collapsed file returns header only", () {
      final file = buildFile(file: "lib/a.dart", hunks: const [], skipReason: null);
      final items = buildFlatList(viewModels: [file], expandedFileIndices: <int>{});
      expect(items, hasLength(1));
      expect(items.single, isA<DiffListFileHeader>());
    });

    test("two files with first expanded and second collapsed", () {
      final fileOne = buildFile(
        file: "lib/a.dart",
        hunks: [
          buildHunk(
            lines: [
              buildLine(
                type: DiffLineType.context,
                content: "line",
                oldLineNumber: 1,
                newLineNumber: 1,
              ),
            ],
          ),
        ],
        skipReason: null,
      );
      final fileTwo = buildFile(file: "lib/b.dart", hunks: const [], skipReason: null);

      final items = buildFlatList(
        viewModels: [fileOne, fileTwo],
        expandedFileIndices: <int>{0},
      );

      expect(items, hasLength(4));
      expect(items[0], isA<DiffListFileHeader>());
      expect(items[1], isA<DiffListHunkHeader>());
      expect(items[2], isA<DiffListLine>());
      expect(items[3], isA<DiffListFileHeader>());
    });

    test("expanded skipped file returns header and skip placeholder", () {
      final file = buildFile(
        file: "lib/a.png",
        hunks: const [],
        skipReason: FileDiffSkipReason.binary,
      );

      final items = buildFlatList(viewModels: [file], expandedFileIndices: <int>{0});

      expect(items, hasLength(2));
      expect(items[0], isA<DiffListFileHeader>());
      expect(items[1], isA<DiffListSkipPlaceholder>());
    });

    test("collapsed skipped file returns header only", () {
      final file = buildFile(
        file: "lib/a.png",
        hunks: const [],
        skipReason: FileDiffSkipReason.binary,
      );

      final items = buildFlatList(viewModels: [file], expandedFileIndices: <int>{});

      expect(items, hasLength(1));
      expect(items.single, isA<DiffListFileHeader>());
    });
  });
}

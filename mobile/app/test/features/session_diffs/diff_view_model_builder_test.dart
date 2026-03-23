import 'package:flutter_test/flutter_test.dart';
import 'package:sesori_mobile/features/session_diffs/models/diff_view_model_builder.dart';
import 'package:sesori_shared/sesori_shared.dart';

void main() {
  group('DiffViewModelBuilder', () {
    test('build with empty list returns empty list', () async {
      final actual = await DiffViewModelBuilder.build(const []);
      expect(actual, isEmpty);
    });

    test('build with single FileDiff returns DiffFileViewModel with correct fields', () async {
      const diff = FileDiff(
        file: 'lib/main.dart',
        before: 'void main() {\n  print("hello");\n}',
        after: 'void main() {\n  print("world");\n}',
        additions: 1,
        deletions: 1,
        status: FileDiffStatus.modified,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result, hasLength(1));
      final vm = result.first;
      expect(vm.fileDiff, equals(diff));
      expect(vm.fileName, equals('main.dart'));
      expect(vm.language, equals('dart'));
      expect(vm.hunks, isNotEmpty);
      expect(vm.additions, greaterThan(0));
      expect(vm.deletions, greaterThan(0));
      expect(vm.status, equals(FileDiffStatus.modified));
      expect(vm.isExpanded, isTrue);
      expect(vm.isBinary, isFalse);
    });

    test('build sorts files alphabetically by file path', () async {
      const diffs = [
        FileDiff(
          file: 'z_file.dart',
          before: 'a',
          after: 'b',
          additions: 1,
          deletions: 0,
        ),
        FileDiff(
          file: 'a_file.dart',
          before: 'a',
          after: 'b',
          additions: 1,
          deletions: 0,
        ),
        FileDiff(
          file: 'm_file.dart',
          before: 'a',
          after: 'b',
          additions: 1,
          deletions: 0,
        ),
      ];

      final result = await DiffViewModelBuilder.build(diffs);

      expect(result, hasLength(3));
      expect(result[0].fileDiff.file, equals('a_file.dart'));
      expect(result[1].fileDiff.file, equals('m_file.dart'));
      expect(result[2].fileDiff.file, equals('z_file.dart'));
    });

    test('detectLanguage returns correct language for .dart file', () async {
      const diff = FileDiff(
        file: 'lib/utils/helper.dart',
        before: 'a',
        after: 'b',
        additions: 1,
        deletions: 0,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.language, equals('dart'));
    });

    test('detectLanguage returns correct language for .ts file', () async {
      const diff = FileDiff(
        file: 'src/index.ts',
        before: 'a',
        after: 'b',
        additions: 1,
        deletions: 0,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.language, equals('typescript'));
    });

    test('detectLanguage returns null for unsupported extension', () async {
      const diff = FileDiff(
        file: 'README.md',
        before: 'a',
        after: 'b',
        additions: 1,
        deletions: 0,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.language, isNull);
    });

    test('fileName is just the last path segment', () async {
      const diff = FileDiff(
        file: 'lib/src/utils/helper.dart',
        before: 'a',
        after: 'b',
        additions: 1,
        deletions: 0,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.fileName, equals('helper.dart'));
    });

    test('hunks contain DiffLineViewModels with correct DiffLines', () async {
      const diff = FileDiff(
        file: 'test.dart',
        before: 'line1\nline2\nline3',
        after: 'line1\nmodified\nline3',
        additions: 1,
        deletions: 1,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.hunks, isNotEmpty);
      final hunk = result.first.hunks.first;
      expect(hunk.lines, isNotEmpty);
      for (final lineVm in hunk.lines) {
        expect(lineVm.line, isNotNull);
        expect(lineVm.highlightedSpan, isNull); // Not set by builder
      }
    });

    test('status is derived as added when before is empty and after is not', () async {
      const diff = FileDiff(
        file: 'new_file.dart',
        before: '',
        after: 'void main() {}',
        additions: 1,
        deletions: 0,
        status: null,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.status, equals(FileDiffStatus.added));
    });

    test('status is derived as deleted when after is empty and before is not', () async {
      const diff = FileDiff(
        file: 'old_file.dart',
        before: 'void main() {}',
        after: '',
        additions: 0,
        deletions: 1,
        status: null,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.status, equals(FileDiffStatus.deleted));
    });

    test('status is derived as modified when both before and after are non-empty', () async {
      const diff = FileDiff(
        file: 'modified_file.dart',
        before: 'void main() {}',
        after: 'void main() { print("hi"); }',
        additions: 1,
        deletions: 0,
        status: null,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.status, equals(FileDiffStatus.modified));
    });

    test('isBinary is true for PNG files', () async {
      const diff = FileDiff(
        file: 'image.png',
        before: '',
        after: '',
        additions: 0,
        deletions: 0,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.isBinary, isTrue);
    });

    test('binary files skip diff computation and have no hunks', () async {
      const diff = FileDiff(
        file: 'image.png',
        before: 'old-binary-bytes',
        after: 'new-binary-bytes',
        additions: 1,
        deletions: 1,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.isBinary, isTrue);
      expect(result.first.hunks, isEmpty);
      expect(result.first.additions, equals(0));
      expect(result.first.deletions, equals(0));
    });

    test('isBinary is false for text files', () async {
      const diff = FileDiff(
        file: 'main.dart',
        before: 'void main() {}',
        after: 'void main() {}',
        additions: 0,
        deletions: 0,
      );

      final result = await DiffViewModelBuilder.build([diff]);

      expect(result.first.isBinary, isFalse);
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_dart_core/sesori_dart_core.dart';
import 'package:sesori_shared/sesori_shared.dart';

import '../utils/binary_detector.dart';
import '../utils/diff_highlighter.dart';
import 'diff_file_view_model.dart';

/// Builds view models for file diffs.
/// Runs DiffEngine.computeDiff in an isolate via compute() for each file.
class DiffViewModelBuilder {
  /// Builds view models for a list of file diffs.
  /// Runs DiffEngine.computeDiff in an isolate via compute() for each file.
  /// Pre-computes syntax highlighting spans via [DiffHighlighter] if initialized.
  static Future<List<DiffFileViewModel>> build(List<FileDiff> diffs) async {
    final results = <DiffFileViewModel>[];
    for (final diff in diffs) {
      final fileName = p.posix.basename(diff.file);

      // Detect binary files
      final isBinary = isBinaryFile(
        diff.file,
        diff.before.isNotEmpty ? diff.before : diff.after,
      );

      if (isBinary) {
        final derivedStatus = diff.status ?? _deriveStatus(diff.before, diff.after);
        results.add(
          DiffFileViewModel(
            fileDiff: diff,
            fileName: fileName,
            language: null,
            hunks: const [],
            additions: 0,
            deletions: 0,
            status: derivedStatus,
            isBinary: true,
          ),
        );
        continue;
      }

      final fileResult = await compute(_computeFileDiff, (diff.before, diff.after));
      final language = detectLanguage(diff.file);

      // Derive status if null
      final derivedStatus = diff.status ?? _deriveStatus(diff.before, diff.after);

      final hunks = fileResult.hunks
          .map(
            (hunk) => DiffHunkViewModel(
              hunk: hunk,
              lines: hunk.lines.map((line) => DiffLineViewModel(line: line)).toList(),
            ),
          )
          .toList();

      // Pre-compute syntax highlighting spans outside the widget build phase.
      for (final hunk in hunks) {
        for (final lineViewModel in hunk.lines) {
          lineViewModel.highlightedSpan = DiffHighlighter.highlightLine(
            lineViewModel.line.content,
            language,
          );
        }
      }

      results.add(
        DiffFileViewModel(
          fileDiff: diff,
          fileName: fileName,
          language: language,
          hunks: hunks,
          additions: fileResult.additions,
          deletions: fileResult.deletions,
          status: derivedStatus,
          isBinary: isBinary,
        ),
      );
    }
    // Sort alphabetically by file path
    results.sort((a, b) => a.fileDiff.file.compareTo(b.fileDiff.file));
    return results;
  }

  /// Top-level function for compute() — must be top-level or static.
  /// Computes diff for a pair of file contents.
  static DiffFileResult _computeFileDiff((String before, String after) args) {
    return DiffEngine.computeDiff(args.$1, args.$2);
  }

  /// Derives FileDiffStatus from before/after content when status is null.
  static FileDiffStatus _deriveStatus(String before, String after) {
    if (before.isEmpty && after.isNotEmpty) return FileDiffStatus.added;
    if (before.isNotEmpty && after.isEmpty) return FileDiffStatus.deleted;
    return FileDiffStatus.modified;
  }
}

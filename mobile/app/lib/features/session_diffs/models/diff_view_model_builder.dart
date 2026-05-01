import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_dart_core/sesori_dart_core.dart';
import 'package:sesori_shared/sesori_shared.dart';

import '../utils/diff_highlighter.dart';
import 'diff_file_view_model.dart';

/// Builds view models for file diffs.
/// Runs DiffEngine.computeDiff in an isolate via compute() for each file.
class DiffViewModelBuilder {
  /// Builds view models for a list of file diffs.
  /// Runs DiffEngine.computeDiff in an isolate via compute() for each file.
  /// Pre-computes syntax highlighting spans via [DiffHighlighter] if initialized.
  static Future<List<DiffFileViewModel>> build(
    List<FileDiff> diffs, {
    Brightness brightness = Brightness.light,
  }) async {
    await DiffHighlighter.initialize(brightness: brightness);
    final results = <DiffFileViewModel>[];
    for (final diff in diffs) {
      switch (diff) {
        case FileDiffContent(
          :final file,
          :final before,
          :final after,
          :final additions,
          :final deletions,
          :final status,
        ):
          final fileName = p.posix.basename(file);
          final fileResult = await compute(_computeFileDiff, (before, after));
          final language = detectLanguage(filePath: file);
          final derivedStatus = status ?? _deriveStatus(before, after);

          final hunks = fileResult.hunks
              .map(
                (hunk) => DiffHunkViewModel(
                  hunk: hunk,
                  lines: hunk.lines.map((line) => DiffLineViewModel(line: line)).toList(),
                ),
              )
              .toList();

          for (final hunk in hunks) {
            for (final lineViewModel in hunk.lines) {
              lineViewModel.highlightedSpan = DiffHighlighter.highlightLine(
                content: lineViewModel.line.content,
                language: language,
              );
            }
          }

          results.add(
            DiffFileViewModel(
              fileDiff: diff,
              fileName: fileName,
              language: language,
              hunks: hunks,
              additions: additions,
              deletions: deletions,
              status: derivedStatus,
            ),
          );
        case FileDiffSkipped(:final file, :final reason, :final status):
          results.add(
            DiffFileViewModel(
              fileDiff: diff,
              fileName: p.posix.basename(file),
              language: null,
              hunks: const [],
              additions: 0,
              deletions: 0,
              status: status,
              skipReason: reason,
            ),
          );
      }
    }
    // Sort alphabetically by file path
    results.sort((a, b) => a.fileDiff.file.compareTo(b.fileDiff.file));
    return results;
  }

  /// Top-level function for compute() — must be top-level or static.
  /// Computes diff for a pair of file contents.
  static DiffFileResult _computeFileDiff((String before, String after) args) {
    return DiffEngine.computeDiff(before: args.$1, after: args.$2);
  }

  /// Derives FileDiffStatus from before/after content when status is null.
  static FileDiffStatus _deriveStatus(String before, String after) {
    if (before.isEmpty && after.isNotEmpty) return FileDiffStatus.added;
    if (before.isNotEmpty && after.isEmpty) return FileDiffStatus.deleted;
    return FileDiffStatus.modified;
  }
}

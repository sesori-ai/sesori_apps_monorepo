import 'package:material_ui/material_ui.dart';
import 'package:sesori_dart_core/sesori_dart_core.dart';
import 'package:sesori_shared/sesori_shared.dart';

/// View-model for a single diff line.
/// Extends DiffLine with optional syntax highlighting span.
class const DiffLineViewModel({
  required final DiffLine line,
  final TextSpan? highlightedSpan,
});

/// View-model for a hunk (group of related changes).
class const DiffHunkViewModel({
  required final DiffHunk hunk,
  required final List<DiffLineViewModel> lines,
});

/// View-model for a whole file diff.
/// Aggregates hunks, metadata, and file-level stats.
class const DiffFileViewModel({
  required final FileDiff fileDiff,
  required final String fileName,
  final String? language,
  required final List<DiffHunkViewModel> hunks,
  required final int additions,
  required final int deletions,
  final FileDiffStatus? status,
  final FileDiffSkipReason? skipReason,
});

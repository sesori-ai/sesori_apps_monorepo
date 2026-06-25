import 'package:flutter/material.dart';
import 'package:sesori_dart_core/sesori_dart_core.dart';
import 'package:sesori_shared/sesori_shared.dart';

/// View-model for a single diff line.
/// Extends DiffLine with optional syntax highlighting span.
class DiffLineViewModel {
  final DiffLine line;
  final TextSpan? highlightedSpan;

  const DiffLineViewModel({
    required this.line,
    this.highlightedSpan,
  });
}

/// View-model for a hunk (group of related changes).
class DiffHunkViewModel {
  final DiffHunk hunk;
  final List<DiffLineViewModel> lines;

  const DiffHunkViewModel({
    required this.hunk,
    required this.lines,
  });
}

/// View-model for a whole file diff.
/// Aggregates hunks, metadata, and file-level stats.
class DiffFileViewModel {
  final FileDiff fileDiff;
  final String fileName;
  final String? language;
  final List<DiffHunkViewModel> hunks;
  final int additions;
  final int deletions;
  final FileDiffStatus? status;
  final FileDiffSkipReason? skipReason;

  const DiffFileViewModel({
    required this.fileDiff,
    required this.fileName,
    this.language,
    required this.hunks,
    required this.additions,
    required this.deletions,
    this.status,
    this.skipReason,
  });
}

import 'package:flutter/material.dart';
import 'package:sesori_dart_core/src/utils/diff/diff_engine.dart';
import 'package:sesori_shared/sesori_shared.dart';

/// View-model for a single diff line.
/// Extends DiffLine with optional syntax highlighting span.
class DiffLineViewModel {
  final DiffLine line;

  /// Mutable — pre-computed by [DiffViewModelBuilder] outside the widget tree.
  TextSpan? highlightedSpan;

  DiffLineViewModel({
    required this.line,
    this.highlightedSpan,
  });
}

/// View-model for a hunk (group of related changes).
/// Includes mutable expansion state for UI collapse/expand.
class DiffHunkViewModel {
  final DiffHunk hunk;
  final List<DiffLineViewModel> lines;
  bool isExpanded;

  DiffHunkViewModel({
    required this.hunk,
    required this.lines,
    this.isExpanded = true,
  });
}

/// View-model for a whole file diff.
/// Aggregates hunks, metadata, and mutable UI state.
class DiffFileViewModel {
  final FileDiff fileDiff;
  final String fileName;
  final String? language;
  final List<DiffHunkViewModel> hunks;
  final int additions;
  final int deletions;
  final FileDiffStatus? status;
  bool isExpanded;
  final bool isBinary;

  DiffFileViewModel({
    required this.fileDiff,
    required this.fileName,
    this.language,
    required this.hunks,
    required this.additions,
    required this.deletions,
    this.status,
    this.isExpanded = true,
    this.isBinary = false,
  });
}

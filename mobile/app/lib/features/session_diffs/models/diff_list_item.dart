import "package:sesori_shared/sesori_shared.dart" show FileDiffSkipReason;

import "diff_file_view_model.dart";

/// Represents a single item in the flat diff list view.
sealed class DiffListItem {
  const DiffListItem();
}

final class DiffListFileHeader extends DiffListItem {
  final DiffFileViewModel viewModel;
  final int fileIndex;
  final bool isExpanded;

  const DiffListFileHeader({
    required this.viewModel,
    required this.fileIndex,
    required this.isExpanded,
  });
}

final class DiffListHunkHeader extends DiffListItem {
  final DiffHunkViewModel viewModel;

  const DiffListHunkHeader({required this.viewModel});
}

final class DiffListLine extends DiffListItem {
  final DiffLineViewModel viewModel;

  const DiffListLine({required this.viewModel});
}

final class DiffListSkipPlaceholder extends DiffListItem {
  final FileDiffSkipReason reason;

  const DiffListSkipPlaceholder({required this.reason});
}

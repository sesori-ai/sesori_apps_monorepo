import "diff_file_view_model.dart";
import "diff_list_item.dart";

/// Builds a flat list of [DiffListItem]s from file view models.
/// Expanded files show their hunk headers + lines; collapsed show only the file header.
List<DiffListItem> buildFlatList({
  required List<DiffFileViewModel> viewModels,
  required Set<int> expandedFileIndices,
}) {
  final items = <DiffListItem>[];
  for (var i = 0; i < viewModels.length; i++) {
    final vm = viewModels[i];
    final isExpanded = expandedFileIndices.contains(i);
    items.add(
      DiffListFileHeader(
        viewModel: vm,
        fileIndex: i,
        isExpanded: isExpanded,
      ),
    );
    if (isExpanded) {
      if (vm.skipReason != null) {
        items.add(DiffListSkipPlaceholder(reason: vm.skipReason!));
      } else {
        for (final hunk in vm.hunks) {
          items.add(DiffListHunkHeader(viewModel: hunk));
          for (final line in hunk.lines) {
            items.add(DiffListLine(viewModel: line));
          }
        }
      }
    }
  }
  return items;
}

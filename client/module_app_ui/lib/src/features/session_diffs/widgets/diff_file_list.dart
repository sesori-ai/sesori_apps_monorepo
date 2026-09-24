import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../models/diff_file_view_model.dart";

/// Every changed file with its status and counts; a tap selects that file.
class const DiffFileList({
  super.key,
  required final List<DiffFileViewModel> viewModels,

  /// The file shown beside the list; null where the list jumps instead.
  required final int? selectedIndex,
  required final void Function(int index) onSelect,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return PregoGroupedRows(
      children: [
        for (final (index, vm) in viewModels.indexed)
          Material(
            key: ValueKey("diff-file-list-$index"),
            color: index == selectedIndex ? prego.colors.textBrandPrimary.withValues(alpha: 0.14) : Colors.transparent,
            child: PregoGroupedRow(
              minHeight: 48,
              verticalPadding: PregoSpacing.sm,
              leading: DiffStatusLetter(status: vm.status),
              title: Text(vm.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: switch (p.posix.dirname(vm.fileDiff.file)) {
                "." => null,
                final folder => Text(folder, maxLines: 1, overflow: TextOverflow.ellipsis),
              },
              trailing: DiffCounts(additions: vm.additions, deletions: vm.deletions, style: prego.textTheme.code),
              onTap: () => onSelect(index),
            ),
          ),
      ],
    );
  }
}

/// A file's +/− counts; a zero side says nothing, so it is left out.
class const DiffCounts({
  super.key,
  required final int additions,
  required final int deletions,
  required final TextStyle style,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: PregoSpacing.xs,
      children: [
        if (additions > 0) Text("+$additions", style: style.copyWith(color: colors.textSuccessPrimary)),
        if (deletions > 0) Text("−$deletions", style: style.copyWith(color: colors.textErrorPrimary)),
      ],
    );
  }
}

/// A, D or M in the status colour.
class const DiffStatusLetter({super.key, required final FileDiffStatus? status}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final (label, color) = switch (status) {
      FileDiffStatus.added => ("A", colors.textSuccessPrimary),
      FileDiffStatus.deleted => ("D", colors.textErrorPrimary),
      FileDiffStatus.modified || null => ("M", colors.textWarningPrimary),
    };
    return Text(
      label,
      style: context.prego.textTheme.code.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

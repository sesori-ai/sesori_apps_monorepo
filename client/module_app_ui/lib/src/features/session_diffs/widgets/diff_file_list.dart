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
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final rows = [
      for (final (index, vm) in viewModels.indexed)
        Semantics(
          key: ValueKey("diff-file-list-$index"),
          selected: selectedIndex == null ? null : index == selectedIndex,
          child: Material(
            color: index == selectedIndex && !pointer
                ? prego.colors.textBrandPrimary.withValues(alpha: 0.14)
                : Colors.transparent,
            child: Stack(
              children: [
                if (index == selectedIndex && pointer)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(PregoSpacing.xs),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: prego.colors.pointerSelectionFill,
                          borderRadius: BorderRadius.circular(PregoRadius.md),
                        ),
                      ),
                    ),
                  ),
                PregoGroupedRow(
                  minHeight: 48,
                  verticalPadding: PregoSpacing.sm,
                  leading: Padding(
                    // The folder's line, under a pointer, so the letter sits on the name's.
                    padding: EdgeInsetsDirectional.only(
                      bottom: pointer && p.posix.dirname(vm.fileDiff.file) != "." ? 16 : 0,
                    ),
                    child: DiffStatusLetter(status: vm.status),
                  ),
                  // The extension is what tells two similar names apart.
                  title: PregoEllipsisText(
                    text: vm.fileName,
                    ellipsis: PregoEllipsis.middle,
                    style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                  ),
                  subtitle: switch (p.posix.dirname(vm.fileDiff.file)) {
                    "." => null,
                    final folder => Text(folder, maxLines: 1, overflow: TextOverflow.ellipsis),
                  },
                  trailing: Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: pointer && p.posix.dirname(vm.fileDiff.file) != "." ? 16 : 0,
                    ),
                    child: DiffCounts(additions: vm.additions, deletions: vm.deletions, style: prego.textTheme.code),
                  ),
                  onTap: () => onSelect(index),
                ),
              ],
            ),
          ),
        ),
    ];
    // Under a pointer it sits flush beside the diff, with no card of its own.
    return pointer
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final row in rows) PregoGroupedRowPosition(isLast: true, child: row)],
          )
        : PregoGroupedRows(children: rows);
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
      // Grey, not amber: amber means "needs you", and a modified file does not.
      FileDiffStatus.modified || null => ("M", colors.textSecondary),
    };
    return Text(
      label,
      style: context.prego.textTheme.code.copyWith(
        color: color,
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
        fontWeight: PregoInteractionScope.of(context) == PregoInteractionMode.pointer
            ? FontWeight.w500
            : FontWeight.w600,
      ),
    );
  }
}

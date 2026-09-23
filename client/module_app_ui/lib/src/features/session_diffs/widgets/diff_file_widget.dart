import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";

import "package:theme_prego/module_prego.dart";

import "../models/diff_file_view_model.dart";
import "../utils/diff_theme.dart";

/// Renders a single file diff header with file name, +/- stats,
/// status badge, and expand/collapse chevron.
class const DiffFileWidget({
  super.key,
  required final DiffFileViewModel viewModel,
  required final bool isExpanded,
  required final VoidCallback onToggle,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: GestureDetector(
        onTap: onToggle,
        child: _buildHeader(context),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final vm = viewModel;
    final theme = DiffTheme.of(context);
    final prego = context.prego;
    final code = prego.textTheme.code;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.fileHeaderBg,
        border: Border(
          bottom: BorderSide(color: theme.fileHeaderBorder, width: 0.5),
        ),
      ),
      child: Row(
        spacing: PregoSpacing.xs,
        children: [
          Expanded(
            child: Text(
              vm.fileName,
              style: code.copyWith(fontWeight: FontWeight.w500, color: prego.colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // A zero side says nothing, so it is left out.
          if (vm.additions > 0) Text("+${vm.additions}", style: code.copyWith(color: prego.colors.textSuccessPrimary)),
          if (vm.deletions > 0) Text("−${vm.deletions}", style: code.copyWith(color: prego.colors.textErrorPrimary)),
          _buildStatusLetter(context: context, status: vm.status),
          Icon(
            isExpanded ? TablerRegular.chevron_up : TablerRegular.chevron_down,
            size: PregoIconSize.md,
            color: theme.chevronColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLetter({required BuildContext context, required FileDiffStatus? status}) {
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

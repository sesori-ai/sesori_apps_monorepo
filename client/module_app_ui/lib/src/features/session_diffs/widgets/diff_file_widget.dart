import "package:material_ui/material_ui.dart";

import "package:theme_prego/module_prego.dart";

import "../models/diff_file_view_model.dart";
import "../utils/diff_theme.dart";
import "diff_file_list.dart";

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
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onToggle,
          child: _buildHeader(context),
        ),
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
          // A skipped file has no counts, and an empty slot would still take a gap.
          if (vm.additions > 0 || vm.deletions > 0)
            DiffCounts(additions: vm.additions, deletions: vm.deletions, style: code),
          DiffStatusLetter(status: vm.status),
          Icon(
            isExpanded ? TablerRegular.chevron_up : TablerRegular.chevron_down,
            size: PregoIconSize.md,
            color: theme.chevronColor,
          ),
        ],
      ),
    );
  }
}

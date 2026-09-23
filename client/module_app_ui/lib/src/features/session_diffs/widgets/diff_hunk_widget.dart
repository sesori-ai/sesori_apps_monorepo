import "package:material_ui/material_ui.dart";

import "package:theme_prego/module_prego.dart";

import "../models/diff_file_view_model.dart";
import "../utils/diff_theme.dart";

/// Renders a diff hunk header showing the @@ range.
class const DiffHunkWidget({super.key, required final DiffHunkViewModel viewModel}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = DiffTheme.of(context);
    final headerTextStyle = context.prego.textTheme.code;

    return SelectionContainer.disabled(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.hunkHeaderBg,
          border: Border(
            bottom: BorderSide(color: theme.hunkHeaderBorder, width: 0.5),
          ),
        ),
        child: Text(
          viewModel.hunk.header,
          style: headerTextStyle.copyWith(color: theme.hunkHeaderText),
        ),
      ),
    );
  }
}

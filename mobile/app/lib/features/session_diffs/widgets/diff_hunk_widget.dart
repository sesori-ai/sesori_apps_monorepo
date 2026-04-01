import "package:flutter/material.dart";

import "../models/diff_file_view_model.dart";
import "../utils/diff_theme.dart";
import "diff_line_widget.dart";

/// Renders a diff hunk: a header bar showing the @@ range, followed by all
/// diff lines in the hunk.
class DiffHunkWidget extends StatelessWidget {
  final DiffHunkViewModel viewModel;

  const DiffHunkWidget({super.key, required this.viewModel});

  static const _headerTextStyle = TextStyle(
    fontFamily: "monospace",
    fontSize: 11,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final theme = DiffTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hunk header: "@@ -X,Y +A,B @@"
        Container(
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
            style: _headerTextStyle.copyWith(color: theme.hunkHeaderText),
          ),
        ),
        // Lines
        ...viewModel.lines.map(
          (line) => DiffLineWidget(viewModel: line),
        ),
      ],
    );
  }
}

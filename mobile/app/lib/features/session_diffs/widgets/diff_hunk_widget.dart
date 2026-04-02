import "package:flutter/material.dart";

import "../models/diff_file_view_model.dart";
import "../utils/diff_theme.dart";

/// Renders a diff hunk header showing the @@ range.
class DiffHunkWidget extends StatelessWidget {
  final DiffHunkViewModel viewModel;

  const DiffHunkWidget({super.key, required this.viewModel});

  static const _headerTextStyle = TextStyle(
    fontFamily: "monospace",
    fontSize: 12,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final theme = DiffTheme.of(context);

    return Container(
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
    );
  }
}

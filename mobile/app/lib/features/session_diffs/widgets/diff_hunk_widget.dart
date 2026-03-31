import "package:flutter/material.dart";

import "../models/diff_file_view_model.dart";
import "diff_line_widget.dart";

/// Renders a diff hunk: a header bar showing the @@ range, followed by all
/// diff lines in the hunk.
class DiffHunkWidget extends StatelessWidget {
  final DiffHunkViewModel viewModel;

  const DiffHunkWidget({super.key, required this.viewModel});

  /// GitHub-style hunk header background (light blue).
  static const _headerBg = Color(0xFFF1F8FF);
  static const _headerBorder = Color(0xFFD1E5F0);

  static const _headerTextStyle = TextStyle(
    fontFamily: "monospace",
    fontSize: 11,
    height: 1.4,
    color: Color(0xFF57606A),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hunk header: "@@ -X,Y +A,B @@"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
            color: _headerBg,
            border: Border(
              bottom: BorderSide(color: _headerBorder, width: 0.5),
            ),
          ),
          child: Text(
            viewModel.hunk.header,
            style: _headerTextStyle,
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

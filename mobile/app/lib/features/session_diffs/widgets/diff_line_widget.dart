import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../models/diff_file_view_model.dart";

/// Renders a single diff line with colored background, gutter line numbers,
/// +/-/space prefix, and horizontally scrollable content.
class DiffLineWidget extends StatelessWidget {
  final DiffLineViewModel viewModel;

  const DiffLineWidget({super.key, required this.viewModel});

  // Background colors (GitHub-style)
  static const _addedBg = Color(0xFFE6FFEC);
  static const _removedBg = Color(0xFFFFEBE9);

  // Gutter colors (slightly more saturated)
  static const _addedGutter = Color(0xFFCCFFC9);
  static const _removedGutter = Color(0xFFFFDBD9);
  static const _contextGutter = Color(0xFFF8F8F8);

  static const _monoStyle = TextStyle(
    fontFamily: "monospace",
    fontSize: 11,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final line = viewModel.line;

    final bg = switch (line.type) {
      DiffLineType.added => _addedBg,
      DiffLineType.removed => _removedBg,
      DiffLineType.context => Colors.transparent,
    };

    final gutterBg = switch (line.type) {
      DiffLineType.added => _addedGutter,
      DiffLineType.removed => _removedGutter,
      DiffLineType.context => _contextGutter,
    };

    final prefix = switch (line.type) {
      DiffLineType.added => "+",
      DiffLineType.removed => "-",
      DiffLineType.context => " ",
    };

    return ColoredBox(
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gutter: old line number
          Container(
            color: gutterBg,
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            alignment: Alignment.centerRight,
            child: Text(
              line.oldLineNumber != null ? "${line.oldLineNumber}" : "",
              style: _monoStyle.copyWith(
                color: const Color(0xFF999999),
              ),
            ),
          ),
          // Gutter: new line number
          Container(
            color: gutterBg,
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            alignment: Alignment.centerRight,
            child: Text(
              line.newLineNumber != null ? "${line.newLineNumber}" : "",
              style: _monoStyle.copyWith(
                color: const Color(0xFF999999),
              ),
            ),
          ),
          // Prefix: +/-/space
          Container(
            color: gutterBg,
            width: 16,
            padding: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            child: Text(
              prefix,
              style: _monoStyle.copyWith(
                color: const Color(0xFF666666),
              ),
            ),
          ),
          // Content: horizontal scroll for long lines
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                child: viewModel.highlightedSpan != null
                    ? Text.rich(viewModel.highlightedSpan!)
                    : Text(line.content, style: _monoStyle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

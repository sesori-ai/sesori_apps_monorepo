import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../models/diff_file_view_model.dart";
import "../utils/diff_theme.dart";

/// Renders a single diff line with colored background, single gutter line number,
/// +/-/space prefix, and wrapping content.
class DiffLineWidget extends StatelessWidget {
  final DiffLineViewModel viewModel;

  const DiffLineWidget({super.key, required this.viewModel});

  static const _monoStyle = TextStyle(
    fontFamily: "monospace",
    fontSize: 12,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final line = viewModel.line;
    final theme = DiffTheme.of(context);

    final bg = switch (line.type) {
      DiffLineType.added => theme.addedBg,
      DiffLineType.removed => theme.removedBg,
      DiffLineType.context => theme.contextBg,
    };

    final gutterBg = switch (line.type) {
      DiffLineType.added => theme.addedGutter,
      DiffLineType.removed => theme.removedGutter,
      DiffLineType.context => theme.contextGutter,
    };

    final prefix = switch (line.type) {
      DiffLineType.added => "+",
      DiffLineType.removed => "-",
      DiffLineType.context => " ",
    };

    final lineNumber = switch (line.type) {
      DiffLineType.context => line.newLineNumber,
      DiffLineType.removed => line.oldLineNumber,
      DiffLineType.added => line.newLineNumber,
    };

    return ColoredBox(
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gutter: single line number
          Container(
            color: gutterBg,
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            alignment: Alignment.centerRight,
            child: Text(
              lineNumber != null ? "$lineNumber" : "",
              style: _monoStyle.copyWith(color: theme.lineNumberText),
            ),
          ),
          // Prefix: +/-/space
          Container(
            color: gutterBg,
            width: 16,
            padding: const EdgeInsetsDirectional.only(top: 1),
            alignment: Alignment.center,
            child: Text(
              prefix,
              style: _monoStyle.copyWith(color: theme.prefixText),
            ),
          ),
          // Content: wraps naturally
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: switch (viewModel.highlightedSpan) {
                null => Text(
                  line.content,
                  style: _monoStyle.copyWith(color: theme.codeText),
                  softWrap: true,
                ),
                final highlightedSpan => Text.rich(
                  highlightedSpan,
                  softWrap: true,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

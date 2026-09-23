import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../models/diff_file_view_model.dart";
import "../utils/diff_theme.dart";

/// Renders a single diff line with colored background, single gutter line number,
/// +/-/space prefix, and wrapping content.
class const DiffLineWidget({super.key, required final DiffLineViewModel viewModel}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final line = viewModel.line;
    final theme = DiffTheme.of(context);
    final monoStyle = context.prego.textTheme.code;

    final bg = switch (line.type) {
      DiffLineType.added => theme.addedBg,
      DiffLineType.removed => theme.removedBg,
      DiffLineType.context => theme.contextBg,
    };

    final bar = switch (line.type) {
      DiffLineType.added => theme.addedBar,
      DiffLineType.removed => theme.removedBar,
      DiffLineType.context => Colors.transparent,
    };

    final prefix = switch (line.type) {
      DiffLineType.added => "+",
      DiffLineType.removed => "-",
      DiffLineType.context => " ",
    };
    final encodedContent = PregoReadableSelectionArea.encodeText(text: line.content);

    final lineNumber = switch (line.type) {
      DiffLineType.context => line.newLineNumber,
      DiffLineType.removed => line.oldLineNumber,
      DiffLineType.added => line.newLineNumber,
    };

    // The tint and the bar belong to the whole row, so both run the full
    // height of a wrapped line.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: BorderDirectional(start: BorderSide(color: bar, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gutter: single line number. Keep source-copy selections free of
          // presentation-only line numbers.
          SelectionContainer.disabled(
            child: Container(
              // The bar paints over the gutter's first 2 points; the number is right-aligned.
              width: 40,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              alignment: Alignment.centerRight,
              child: Text(
                lineNumber != null ? "$lineNumber" : "",
                style: monoStyle.copyWith(color: theme.lineNumberText),
              ),
            ),
          ),
          // Prefix: +/-/space. The marker is visual metadata rather than file
          // content, so exclude it from a cross-line source selection.
          SelectionContainer.disabled(
            child: Container(
              width: 16,
              padding: const EdgeInsetsDirectional.only(top: 1),
              alignment: Alignment.center,
              child: Text(
                prefix,
                style: monoStyle.copyWith(color: theme.prefixText),
              ),
            ),
          ),
          // Content: wraps naturally
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: switch (viewModel.highlightedSpan) {
                null => Text(
                  encodedContent,
                  style: monoStyle.copyWith(color: theme.codeText),
                  softWrap: true,
                ),
                final highlightedSpan => Text.rich(
                  highlightedSpan,
                  // The span carries colours; the code style gives it the line height.
                  style: monoStyle.copyWith(color: theme.codeText),
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

import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";

MarkdownStyleSheet buildSessionMarkdownStyleSheet(
  ThemeData theme, {
  TextStyle? paragraphStyle,
}) {
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: paragraphStyle,
    codeblockDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    code: TextStyle(
      fontFamily: "monospace",
      fontSize: 13,
      color: theme.colorScheme.onSurface,
    ),
  );
}

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/widgets/markdown_styles.dart";

void main() {
  final theme = ThemeData.light().copyWith(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14),
      bodyLarge: TextStyle(fontSize: 16),
    ),
  );

  test("buildSessionMarkdownStyleSheet applies shared code styling", () {
    final styleSheet = buildSessionMarkdownStyleSheet(theme);

    expect(styleSheet.code?.fontFamily, "monospace");
    expect(styleSheet.code?.fontSize, 13);
    expect(styleSheet.code?.color, theme.colorScheme.onSurface);

    final decoration = styleSheet.codeblockDecoration as BoxDecoration?;
    expect(decoration?.color, theme.colorScheme.surfaceContainerHighest);
    expect(decoration?.borderRadius, BorderRadius.circular(8));
  });

  test("buildSessionMarkdownStyleSheet overrides paragraph style when provided", () {
    const paragraphStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

    final styleSheet = buildSessionMarkdownStyleSheet(theme, paragraphStyle: paragraphStyle);

    expect(styleSheet.p, paragraphStyle);
  });
}

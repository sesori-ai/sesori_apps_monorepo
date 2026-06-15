import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/widgets/markdown_styles.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  final prego = PregoDesignSystem.light;

  test("buildSessionMarkdownStyleSheet applies shared code styling", () {
    final styleSheet = buildSessionMarkdownStyleSheet(prego: prego);

    expect(styleSheet.code?.fontFamily, "monospace");
    expect(styleSheet.code?.fontSize, 13);
    expect(styleSheet.code?.color, prego.colors.textPrimary);

    final decoration = styleSheet.codeblockDecoration as BoxDecoration?;
    expect(decoration?.color, prego.colors.bgQuaternary);
    expect(decoration?.borderRadius, BorderRadius.circular(8));
  });

  test("buildSessionMarkdownStyleSheet overrides paragraph style when provided", () {
    const paragraphStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

    final styleSheet = buildSessionMarkdownStyleSheet(prego: prego, paragraphStyle: paragraphStyle);

    expect(styleSheet.p, paragraphStyle);
  });
}

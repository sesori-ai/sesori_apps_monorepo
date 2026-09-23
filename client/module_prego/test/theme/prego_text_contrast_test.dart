import "dart:math";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

double _contrast({required Color foreground, required Color background}) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (max(a, b) + 0.05) / (min(a, b) + 0.05);
}

void main() {
  for (final (name, colors) in [("light", PregoColors.light), ("dark", PregoColors.dark)]) {
    test("$name tertiary text stays readable and below secondary on page and card surfaces", () {
      for (final background in [colors.bgSurface1, colors.bgSecondary]) {
        final tertiary = _contrast(foreground: colors.textTertiary, background: background);
        expect(tertiary, greaterThanOrEqualTo(4.5));
        expect(_contrast(foreground: colors.textSecondary, background: background), greaterThan(tertiary));
        expect(_contrast(foreground: colors.textQuaternary, background: background), lessThan(tertiary));
      }
    });
  }
}

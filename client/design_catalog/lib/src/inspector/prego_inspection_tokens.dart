import "package:flutter/widgets.dart";
import "package:theme_prego/module_prego.dart";

import "prego_inspection_token.dart";
import "prego_token_catalog.g.dart";

export "prego_inspection_token.dart";

final class const PregoInspectionTokenMatches<T>({
  required final T value,
  required final List<PregoInspectionToken<T>> candidates,
});

final class PregoInspectionTokenResolver({required final BuildContext context}) {
  final List<PregoInspectionToken<Color>> _colors = buildPregoInspectionColorTokens(context.prego.colors);
  final List<PregoInspectionToken<TextStyle>> _typography = buildPregoInspectionTypographyTokens(
    context.prego.textTheme,
  );

  PregoInspectionTokenMatches<Color> matchColor(Color color) {
    final candidates = _colors.where((token) => token.value.toARGB32() == color.toARGB32()).toList(growable: false);
    return PregoInspectionTokenMatches(value: color, candidates: candidates);
  }

  PregoInspectionTokenMatches<TextStyle> matchTypography(TextStyle style) {
    final candidates = _typography
        .where((token) => _sameTypographyMetrics(first: token.value, second: style))
        .toList(growable: false);
    return PregoInspectionTokenMatches(value: style, candidates: candidates);
  }

  PregoInspectionTokenMatches<double> matchDimension(
    double value, {
    required Set<PregoInspectionTokenKind> kinds,
  }) {
    final candidates = pregoInspectionDimensionTokens
        .where((token) => kinds.contains(token.kind) && (token.value - value).abs() < 0.001)
        .toList(growable: false);
    return PregoInspectionTokenMatches(value: value, candidates: candidates);
  }
}

bool _sameTypographyMetrics({required TextStyle first, required TextStyle second}) =>
    first.fontFamily == second.fontFamily &&
    first.fontSize == second.fontSize &&
    first.fontWeight == second.fontWeight &&
    first.fontStyle == second.fontStyle &&
    first.height == second.height &&
    first.letterSpacing == second.letterSpacing;

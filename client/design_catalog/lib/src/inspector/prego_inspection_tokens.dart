// ignore_for_file: no_slop_linter/prefer_required_named_parameters, use_declaring_parameters

import "package:flutter/widgets.dart";
import "package:theme_prego/module_prego.dart";

import "prego_inspection_token.dart";
import "prego_token_catalog.g.dart";

export "prego_inspection_token.dart";

final class const PregoInspectionTokenMatches<T>({
  required this.value,
  required this.candidates,
}) {
  final T value;
  final List<PregoInspectionToken<T>> candidates;

  bool get isMapped => candidates.isNotEmpty;
  bool get isAmbiguous => candidates.length > 1;
}

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
    final candidates = _typography.where((token) => _sameTypographyMetrics(token.value, style)).toList(growable: false);
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

bool _sameTypographyMetrics(TextStyle first, TextStyle second) =>
    first.fontFamily == second.fontFamily &&
    first.fontSize == second.fontSize &&
    first.fontWeight == second.fontWeight &&
    first.fontStyle == second.fontStyle &&
    first.height == second.height &&
    first.letterSpacing == second.letterSpacing;

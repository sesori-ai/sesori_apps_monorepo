import "package:flutter/material.dart";

import "font/prego_text_theme.dart";
import "primitives/prego_colors.g.dart";
import "primitives/prego_radius.g.dart";
import "primitives/prego_shadows.dart";
import "primitives/prego_spacing.g.dart";
import "primitives/prego_spacing_primitives.g.dart";
import "primitives/prego_widths.g.dart";

/// Container for all Prego design values.
///
/// A [ThemeExtension] that provides colors, spacing, radius, and text styles.
/// Add to [ThemeData.extensions] and access via [context.prego].
///
/// Usage:
/// ```dart
/// final design = context.prego;
/// Container(
///   color: design.colors.bgPrimary,
///   padding: EdgeInsets.all(design.spacing.md),
///   decoration: BoxDecoration(
///     borderRadius: BorderRadius.circular(design.radius.lg),
///   ),
/// )
/// ```
@immutable
// ignore: use_enums, theme extension instances need class semantics and static light/dark singletons
final class PregoDesignSystem extends ThemeExtension<PregoDesignSystem> {
  PregoDesignSystem._({
    required this.colors,
    required this.textTheme,
  }) : shadows = PregoShadows(colors: colors);

  /// Semantic color values that adapt to light/dark mode.
  final PregoColors colors;
  final PregoTextTheme textTheme;

  /// Spacing constants.
  ///
  /// Access via static members: `PregoSpacing.md`, `PregoSpacing.lg`, etc.
  /// This getter provides instance access for consistency with the API.
  PregoSpacingAccessor get spacing => const PregoSpacingAccessor._();

  /// Border radius constants.
  ///
  /// Access via static members: `PregoRadius.md`, `PregoRadius.full`, etc.
  /// This getter provides instance access for consistency with the API.
  PregoRadiusAccessor get radius => const PregoRadiusAccessor._();

  /// Width constants.
  ///
  /// Access via static members: `PregoWidths.md`, `PregoWidths.lg`, etc.
  /// This getter provides instance access for consistency with the API.
  PregoWidthsAccessor get widths => const PregoWidthsAccessor._();

  /// Shadow tokens derived from [colors].
  ///
  /// Each shadow level returns `List<BoxShadow>` with theme-aware colors.
  /// Usage: `context.prego.shadows.sm`
  final PregoShadows shadows;

  /// [PregoDesignSystem] for light mode.
  static final light = PregoDesignSystem._(colors: .light, textTheme: .light);

  /// [PregoDesignSystem] for dark mode.
  static final dark = PregoDesignSystem._(colors: .dark, textTheme: .dark);

  @override
  PregoDesignSystem copyWith({PregoColors? colors, PregoTextTheme? textTheme}) =>
      PregoDesignSystem._(colors: colors ?? this.colors, textTheme: textTheme ?? this.textTheme);

  @override
  ThemeExtension<PregoDesignSystem> lerp(covariant PregoDesignSystem? other, double t) {
    if (other == null) return this;
    return PregoDesignSystem._(
      colors: PregoColors.lerpColors(a: colors, b: other.colors, t: t),
      textTheme: PregoTextTheme.lerpTextThemes(a: textTheme, b: other.textTheme, t: t),
    );
  }
}

/// Provides instance access to [PregoSpacing] constants.
///
/// Allows `context.prego.spacing.md` syntax while keeping
/// spacing values as compile-time constants.
@immutable
final class PregoSpacingAccessor {
  const PregoSpacingAccessor._();

  double get xxs => PregoSpacing.xxs;
  double get xs => PregoSpacing.xs;
  double get sm => PregoSpacing.sm;
  double get md => PregoSpacing.md;
  double get lg => PregoSpacing.lg;
  double get xl => PregoSpacing.xl;
  double get x2l => PregoSpacing.x2l;
  double get x3l => PregoSpacing.x3l;
  double get x4l => PregoSpacing.x4l;
  double get x5l => PregoSpacing.x5l;
  double get x6l => PregoSpacing.x6l;
  double get x7l => PregoSpacing.x7l;
  double get x8l => PregoSpacing.x8l;
  double get x9l => PregoSpacing.x9l;
  double get x10l => PregoSpacing.x10l;
  double get x11l => PregoSpacing.x11l;

  // Numeric access (via PregoSpacingPrimitives)
  double get spacing0 => PregoSpacingPrimitives.spacing0;
  double get spacing0_5 => PregoSpacingPrimitives.spacing0_5;
  double get spacing1 => PregoSpacingPrimitives.spacing1;
  double get spacing1_5 => PregoSpacingPrimitives.spacing1_5;
  double get spacing2 => PregoSpacingPrimitives.spacing2;
  double get spacing3 => PregoSpacingPrimitives.spacing3;
  double get spacing4 => PregoSpacingPrimitives.spacing4;
  double get spacing5 => PregoSpacingPrimitives.spacing5;
  double get spacing6 => PregoSpacingPrimitives.spacing6;
  double get spacing8 => PregoSpacingPrimitives.spacing8;
  double get spacing10 => PregoSpacingPrimitives.spacing10;
  double get spacing12 => PregoSpacingPrimitives.spacing12;
  double get spacing16 => PregoSpacingPrimitives.spacing16;
  double get spacing20 => PregoSpacingPrimitives.spacing20;
  double get spacing24 => PregoSpacingPrimitives.spacing24;
  double get spacing32 => PregoSpacingPrimitives.spacing32;
  double get spacing40 => PregoSpacingPrimitives.spacing40;
  double get spacing48 => PregoSpacingPrimitives.spacing48;
  double get spacing56 => PregoSpacingPrimitives.spacing56;
  double get spacing64 => PregoSpacingPrimitives.spacing64;
  double get spacing80 => PregoSpacingPrimitives.spacing80;
  double get spacing96 => PregoSpacingPrimitives.spacing96;
  double get spacing120 => PregoSpacingPrimitives.spacing120;
  double get spacing140 => PregoSpacingPrimitives.spacing140;
  double get spacing160 => PregoSpacingPrimitives.spacing160;
  double get spacing180 => PregoSpacingPrimitives.spacing180;
  double get spacing192 => PregoSpacingPrimitives.spacing192;
  double get spacing256 => PregoSpacingPrimitives.spacing256;
  double get spacing320 => PregoSpacingPrimitives.spacing320;
  double get spacing360 => PregoSpacingPrimitives.spacing360;
  double get spacing400 => PregoSpacingPrimitives.spacing400;
  double get spacing480 => PregoSpacingPrimitives.spacing480;

  // Container-specific
  double get containerPaddingMobile => PregoSpacing.containerPaddingMobile;
  double get containerPaddingDesktop => PregoSpacing.containerPaddingDesktop;
  double get containerMaxWidthDesktop => PregoSpacing.containerMaxWidthDesktop;
}

/// Provides instance access to [PregoRadius] constants.
///
/// Allows `context.prego.radius.md` syntax while keeping
/// radius values as compile-time constants.
@immutable
final class PregoRadiusAccessor {
  const PregoRadiusAccessor._();

  double get none => PregoRadius.none;
  double get xxs => PregoRadius.xxs;
  double get xs => PregoRadius.xs;
  double get sm => PregoRadius.sm;
  double get md => PregoRadius.md;
  double get lg => PregoRadius.lg;
  double get xl => PregoRadius.xl;
  double get x2l => PregoRadius.x2l;
  double get x3l => PregoRadius.x3l;
  double get x4l => PregoRadius.x4l;
  double get x5l => PregoRadius.x5l;
  double get full => PregoRadius.full;
}

/// Provides instance access to [PregoWidths] constants.
///
/// Allows `context.prego.widths.md` syntax while keeping
/// width values as compile-time constants.
@immutable
final class PregoWidthsAccessor {
  const PregoWidthsAccessor._();

  double get xxs => PregoWidths.xxs;
  double get xs => PregoWidths.xs;
  double get sm => PregoWidths.sm;
  double get md => PregoWidths.md;
  double get lg => PregoWidths.lg;
  double get xl => PregoWidths.xl;
  double get x2l => PregoWidths.x2l;
  double get x3l => PregoWidths.x3l;
  double get x4l => PregoWidths.x4l;
  double get x5l => PregoWidths.x5l;
  double get x6l => PregoWidths.x6l;
  double get paragraphMaxWidth => PregoWidths.paragraphMaxWidth;
}

import "package:flutter/material.dart";

import "font/zyra_text_theme.dart";
import "primitives/zyra_colors.g.dart";
import "primitives/zyra_radius.g.dart";
import "primitives/zyra_shadows.dart";
import "primitives/zyra_spacing.g.dart";
import "primitives/zyra_spacing_primitives.g.dart";
import "primitives/zyra_widths.g.dart";

/// Container for all Zyra design values.
///
/// A [ThemeExtension] that provides colors, spacing, radius, and text styles.
/// Add to [ThemeData.extensions] and access via [context.zyra].
///
/// Usage:
/// ```dart
/// final design = context.zyra;
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
final class ZyraDesignSystem extends ThemeExtension<ZyraDesignSystem> {
  ZyraDesignSystem._({
    required this.colors,
    required this.textTheme,
  }) : shadows = ZyraShadows(colors: colors);

  /// Semantic color values that adapt to light/dark mode.
  final ZyraColors colors;
  final ZyraTextTheme textTheme;

  /// Spacing constants.
  ///
  /// Access via static members: `ZyraSpacing.md`, `ZyraSpacing.lg`, etc.
  /// This getter provides instance access for consistency with the API.
  ZyraSpacingAccessor get spacing => const ZyraSpacingAccessor._();

  /// Border radius constants.
  ///
  /// Access via static members: `ZyraRadius.md`, `ZyraRadius.full`, etc.
  /// This getter provides instance access for consistency with the API.
  ZyraRadiusAccessor get radius => const ZyraRadiusAccessor._();

  /// Width constants.
  ///
  /// Access via static members: `ZyraWidths.md`, `ZyraWidths.lg`, etc.
  /// This getter provides instance access for consistency with the API.
  ZyraWidthsAccessor get widths => const ZyraWidthsAccessor._();

  /// Shadow tokens derived from [colors].
  ///
  /// Each shadow level returns `List<BoxShadow>` with theme-aware colors.
  /// Usage: `context.zyra.shadows.sm`
  final ZyraShadows shadows;

  /// [ZyraDesignSystem] for light mode.
  static final light = ZyraDesignSystem._(colors: .light, textTheme: .light);

  /// [ZyraDesignSystem] for dark mode.
  static final dark = ZyraDesignSystem._(colors: .dark, textTheme: .dark);

  @override
  ZyraDesignSystem copyWith({ZyraColors? colors, ZyraTextTheme? textTheme}) =>
      ZyraDesignSystem._(colors: colors ?? this.colors, textTheme: textTheme ?? this.textTheme);

  @override
  ThemeExtension<ZyraDesignSystem> lerp(covariant ZyraDesignSystem? other, double t) {
    if (other == null) return this;
    return ZyraDesignSystem._(
      colors: ZyraColors.lerpColors(a: colors, b: other.colors, t: t),
      textTheme: ZyraTextTheme.lerpTextThemes(a: textTheme, b: other.textTheme, t: t),
    );
  }
}

/// Provides instance access to [ZyraSpacing] constants.
///
/// Allows `context.zyra.spacing.md` syntax while keeping
/// spacing values as compile-time constants.
@immutable
final class ZyraSpacingAccessor {
  const ZyraSpacingAccessor._();

  double get xxs => ZyraSpacing.xxs;
  double get xs => ZyraSpacing.xs;
  double get sm => ZyraSpacing.sm;
  double get md => ZyraSpacing.md;
  double get lg => ZyraSpacing.lg;
  double get xl => ZyraSpacing.xl;
  double get x2l => ZyraSpacing.x2l;
  double get x3l => ZyraSpacing.x3l;
  double get x4l => ZyraSpacing.x4l;
  double get x5l => ZyraSpacing.x5l;
  double get x6l => ZyraSpacing.x6l;
  double get x7l => ZyraSpacing.x7l;
  double get x8l => ZyraSpacing.x8l;
  double get x9l => ZyraSpacing.x9l;
  double get x10l => ZyraSpacing.x10l;
  double get x11l => ZyraSpacing.x11l;

  // Numeric access (via ZyraSpacingPrimitives)
  double get spacing0 => ZyraSpacingPrimitives.spacing0;
  double get spacing0_5 => ZyraSpacingPrimitives.spacing0_5;
  double get spacing1 => ZyraSpacingPrimitives.spacing1;
  double get spacing1_5 => ZyraSpacingPrimitives.spacing1_5;
  double get spacing2 => ZyraSpacingPrimitives.spacing2;
  double get spacing3 => ZyraSpacingPrimitives.spacing3;
  double get spacing4 => ZyraSpacingPrimitives.spacing4;
  double get spacing5 => ZyraSpacingPrimitives.spacing5;
  double get spacing6 => ZyraSpacingPrimitives.spacing6;
  double get spacing8 => ZyraSpacingPrimitives.spacing8;
  double get spacing10 => ZyraSpacingPrimitives.spacing10;
  double get spacing12 => ZyraSpacingPrimitives.spacing12;
  double get spacing16 => ZyraSpacingPrimitives.spacing16;
  double get spacing20 => ZyraSpacingPrimitives.spacing20;
  double get spacing24 => ZyraSpacingPrimitives.spacing24;
  double get spacing32 => ZyraSpacingPrimitives.spacing32;
  double get spacing40 => ZyraSpacingPrimitives.spacing40;
  double get spacing48 => ZyraSpacingPrimitives.spacing48;
  double get spacing56 => ZyraSpacingPrimitives.spacing56;
  double get spacing64 => ZyraSpacingPrimitives.spacing64;
  double get spacing80 => ZyraSpacingPrimitives.spacing80;
  double get spacing96 => ZyraSpacingPrimitives.spacing96;
  double get spacing120 => ZyraSpacingPrimitives.spacing120;
  double get spacing140 => ZyraSpacingPrimitives.spacing140;
  double get spacing160 => ZyraSpacingPrimitives.spacing160;
  double get spacing180 => ZyraSpacingPrimitives.spacing180;
  double get spacing192 => ZyraSpacingPrimitives.spacing192;
  double get spacing256 => ZyraSpacingPrimitives.spacing256;
  double get spacing320 => ZyraSpacingPrimitives.spacing320;
  double get spacing360 => ZyraSpacingPrimitives.spacing360;
  double get spacing400 => ZyraSpacingPrimitives.spacing400;
  double get spacing480 => ZyraSpacingPrimitives.spacing480;

  // Container-specific
  double get containerPaddingMobile => ZyraSpacing.containerPaddingMobile;
  double get containerPaddingDesktop => ZyraSpacing.containerPaddingDesktop;
  double get containerMaxWidthDesktop => ZyraSpacing.containerMaxWidthDesktop;
}

/// Provides instance access to [ZyraRadius] constants.
///
/// Allows `context.zyra.radius.md` syntax while keeping
/// radius values as compile-time constants.
@immutable
final class ZyraRadiusAccessor {
  const ZyraRadiusAccessor._();

  double get none => ZyraRadius.none;
  double get xxs => ZyraRadius.xxs;
  double get xs => ZyraRadius.xs;
  double get sm => ZyraRadius.sm;
  double get md => ZyraRadius.md;
  double get lg => ZyraRadius.lg;
  double get xl => ZyraRadius.xl;
  double get x2l => ZyraRadius.x2l;
  double get x3l => ZyraRadius.x3l;
  double get x4l => ZyraRadius.x4l;
  double get x5l => ZyraRadius.x5l;
  double get full => ZyraRadius.full;
}

/// Provides instance access to [ZyraWidths] constants.
///
/// Allows `context.zyra.widths.md` syntax while keeping
/// width values as compile-time constants.
@immutable
final class ZyraWidthsAccessor {
  const ZyraWidthsAccessor._();

  double get xxs => ZyraWidths.xxs;
  double get xs => ZyraWidths.xs;
  double get sm => ZyraWidths.sm;
  double get md => ZyraWidths.md;
  double get lg => ZyraWidths.lg;
  double get xl => ZyraWidths.xl;
  double get x2l => ZyraWidths.x2l;
  double get x3l => ZyraWidths.x3l;
  double get x4l => ZyraWidths.x4l;
  double get x5l => ZyraWidths.x5l;
  double get x6l => ZyraWidths.x6l;
  double get paragraphMaxWidth => ZyraWidths.paragraphMaxWidth;
}

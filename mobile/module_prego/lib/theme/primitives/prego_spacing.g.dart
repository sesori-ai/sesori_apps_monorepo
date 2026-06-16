// GENERATED CODE - DO NOT MODIFY BY HAND
// To update, export variables from Figma and run:
//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate

import "prego_spacing_primitives.g.dart";

/// Semantic spacing tokens matching Figma spacing scale.
///
/// Values reference [PregoSpacingPrimitives] where Figma uses an alias.
///
/// Usage:
/// ```dart
/// Padding(padding: EdgeInsetsDirectional.all(PregoSpacing.md))
/// SizedBox(height: PregoSpacing.lg)
/// ```
abstract final class PregoSpacing {
  // ===========================================================================
  // Semantic Spacing - Figma: Spacing collection
  // ===========================================================================

  /// Figma: spacing-none → Spacing/0 (0px)
  static const double none = PregoSpacingPrimitives.spacing0;

  /// Figma: spacing-xxs → Spacing/0․5 (2px)
  static const double xxs = PregoSpacingPrimitives.spacing0_5;

  /// Figma: spacing-xs → Spacing/1 (4px)
  static const double xs = PregoSpacingPrimitives.spacing1;

  /// Figma: spacing-sm → Spacing/1․5 (6px)
  static const double sm = PregoSpacingPrimitives.spacing1_5;

  /// Figma: spacing-md → Spacing/2 (8px)
  static const double md = PregoSpacingPrimitives.spacing2;

  /// Figma: spacing-lg → Spacing/3 (12px)
  static const double lg = PregoSpacingPrimitives.spacing3;

  /// Figma: spacing-xl → Spacing/4 (16px)
  static const double xl = PregoSpacingPrimitives.spacing4;

  /// Figma: spacing-2xl → Spacing/5 (20px)
  static const double x2l = PregoSpacingPrimitives.spacing5;

  /// Figma: spacing-3xl → Spacing/6 (24px)
  static const double x3l = PregoSpacingPrimitives.spacing6;

  /// Figma: spacing-4xl → Spacing/8 (32px)
  static const double x4l = PregoSpacingPrimitives.spacing8;

  /// Figma: spacing-5xl → Spacing/10 (40px)
  static const double x5l = PregoSpacingPrimitives.spacing10;

  /// Figma: spacing-6xl → Spacing/12 (48px)
  static const double x6l = PregoSpacingPrimitives.spacing12;

  /// Figma: spacing-7xl → Spacing/16 (64px)
  static const double x7l = PregoSpacingPrimitives.spacing16;

  /// Figma: spacing-8xl → Spacing/20 (80px)
  static const double x8l = PregoSpacingPrimitives.spacing20;

  /// Figma: spacing-9xl → Spacing/24 (96px)
  static const double x9l = PregoSpacingPrimitives.spacing24;

  /// Figma: spacing-10xl → Spacing/32 (128px)
  static const double x10l = PregoSpacingPrimitives.spacing32;

  /// Figma: spacing-11xl → Spacing/40 (160px)
  static const double x11l = PregoSpacingPrimitives.spacing40;

  // ===========================================================================
  // Container Spacing - Figma: Containers collection
  // ===========================================================================

  /// Figma: container-padding-mobile → Spacing/4 (16px)
  static const double containerPaddingMobile = PregoSpacingPrimitives.spacing4;

  /// Figma: container-padding-desktop → Spacing/8 (32px)
  static const double containerPaddingDesktop = PregoSpacingPrimitives.spacing8;

  /// Figma: container-max-width-desktop → Spacing/320 (1,280px)
  static const double containerMaxWidthDesktop = PregoSpacingPrimitives.spacing320;
}

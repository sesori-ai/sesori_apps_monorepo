/// Zyra Design System
///
/// A comprehensive design system matching Figma specifications.
///
/// ## Quick Start
///
/// Access design values via `context.zyra` anywhere in the widget tree:
///
/// ```dart
/// class MyNewScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       backgroundColor: context.zyra.colors.bgPrimary,
///       body: Padding(
///         padding: EdgeInsets.all(context.zyra.spacing.lg),
///         child: Text(
///           'Hello',
///           style: TextStyle(color: context.zyra.colors.textPrimary),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Available Values
///
/// ### Colors ([ZyraColors], [ZyraColorsDark], [ZyraColorsLight])
/// Semantic colors that adapt to light/dark mode:
/// - `context.zyra.colors.textPrimary` -> Primary text color (instance access)
/// - `ZyraColorsDark.textPrimary` -> Dark mode primary text (static const access)
/// - `ZyraColorsLight.textPrimary` -> Light mode primary text (static const access)
/// - `context.zyra.colors.bgSecondary` -> Secondary background
/// - `context.zyra.colors.borderBrand` -> Brand-colored border
///
/// ### Spacing ([ZyraSpacing])
/// Consistent spacing values matching Figma:
/// - `context.zyra.spacing.md` -> 8px
/// - `context.zyra.spacing.xl` -> 16px
/// - `ZyraSpacingPrimitives.spacing4` -> 16px (static access)
///
/// ### Radius ([ZyraRadius])
/// Border radius values matching Figma:
/// - `context.zyra.radius.md` -> 8px
/// - `context.zyra.radius.full` -> 9999px (pill shape)
/// - `ZyraRadius.lg` -> 10px (static access)
library;

import "package:flutter/material.dart";

import "zyra_design_system.dart";

export 'font/zyra_text_theme.dart';
export "primitives/zyra_colors.g.dart" show ZyraColors, ZyraColorsDark, ZyraColorsLight;
export "primitives/zyra_colors_x.dart";
export "primitives/zyra_radius.g.dart";
export "primitives/zyra_shadows.dart";
export "primitives/zyra_spacing.g.dart";
export "primitives/zyra_spacing_primitives.g.dart";
export "primitives/zyra_widths.g.dart";
export "zyra_design_system.dart";

/// Extension on [BuildContext] to access [ZyraDesignSystem].
///
/// Provides convenient access to design values:
///
/// ```dart
/// // Text Theme
/// context.zyra.textTheme.display2xl.regular
/// context.zyra.textTheme.displayXs.bold
///
/// // Colors
/// context.zyra.colors.textPrimary
/// context.zyra.colors.bgBrandSolid
///
/// // Spacing
/// context.zyra.spacing.md
/// context.zyra.spacing.xl
///
/// // Radius
/// context.zyra.radius.lg
/// context.zyra.radius.full
/// ```
extension ZyraDesignExtension on BuildContext {
  /// Access the Zyra design system values.
  ///
  /// Returns [ZyraDesignSystem] with colors, spacing, radius, and text styles.
  /// Automatically resolves to light or dark mode based on the current [Theme].
  ZyraDesignSystem get zyra {
    final design = Theme.of(this).extension<ZyraDesignSystem>();
    assert(design != null, "ZyraDesignSystem not found in ThemeData.extensions. Add it to your ThemeData.");
    // ignore: no_slop_linter/avoid_bang_operator, assert above guarantees the theme extension is present in debug builds
    return design!;
  }
}

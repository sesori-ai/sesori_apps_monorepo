/// Prego Design System
///
/// A comprehensive design system matching Figma specifications.
///
/// ## Quick Start
///
/// Access design values via `context.prego` anywhere in the widget tree:
///
/// ```dart
/// class MyNewScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       backgroundColor: context.prego.colors.bgSurface1,
///       body: Padding(
///         padding: EdgeInsets.all(context.prego.spacing.lg),
///         child: Text(
///           'Hello',
///           style: TextStyle(color: context.prego.colors.textPrimary),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Available Values
///
/// ### Colors ([PregoColors], [PregoColorsDark], [PregoColorsLight])
/// Semantic colors that adapt to light/dark mode:
/// - `context.prego.colors.textPrimary` -> Primary text color (instance access)
/// - `PregoColorsDark.textPrimary` -> Dark mode primary text (static const access)
/// - `PregoColorsLight.textPrimary` -> Light mode primary text (static const access)
/// - `context.prego.colors.bgSecondary` -> Secondary background
/// - `context.prego.colors.borderBrand` -> Brand-colored border
///
/// ### Spacing ([PregoSpacing])
/// Consistent spacing values matching Figma:
/// - `context.prego.spacing.md` -> 8px
/// - `context.prego.spacing.xl` -> 16px
/// - `PregoSpacingPrimitives.spacing4` -> 16px (static access)
///
/// ### Radius ([PregoRadius])
/// Border radius values matching Figma:
/// - `context.prego.radius.md` -> 8px
/// - `context.prego.radius.full` -> 9999px (pill shape)
/// - `PregoRadius.lg` -> 10px (static access)
library;

import "package:flutter/material.dart";

import "prego_design_system.dart";

export 'font/prego_text_theme.dart';
export "prego_design_system.dart";
export "primitives/prego_colors.g.dart" show PregoColors, PregoColorsDark, PregoColorsLight;
export "primitives/prego_colors_x.dart";
export "primitives/prego_radius.g.dart";
export "primitives/prego_shadows.dart";
export "primitives/prego_spacing.g.dart";
export "primitives/prego_spacing_primitives.g.dart";
export "primitives/prego_widths.g.dart";

/// Extension on [BuildContext] to access [PregoDesignSystem].
///
/// Provides convenient access to design values:
///
/// ```dart
/// // Text Theme
/// context.prego.textTheme.display2xl.regular
/// context.prego.textTheme.displayXs.bold
///
/// // Colors
/// context.prego.colors.textPrimary
/// context.prego.colors.bgBrandSolid
///
/// // Spacing
/// context.prego.spacing.md
/// context.prego.spacing.xl
///
/// // Radius
/// context.prego.radius.lg
/// context.prego.radius.full
/// ```
extension PregoDesignExtension on BuildContext {
  /// Access the Prego design system values.
  ///
  /// Returns [PregoDesignSystem] with colors, spacing, radius, and text styles.
  /// Automatically resolves to light or dark mode based on the current [Theme].
  PregoDesignSystem get prego {
    final design = Theme.of(this).extension<PregoDesignSystem>();
    assert(design != null, "PregoDesignSystem not found in ThemeData.extensions. Add it to your ThemeData.");
    // ignore: no_slop_linter/avoid_bang_operator, assert above guarantees the theme extension is present in debug builds
    return design!;
  }
}

// ignore_for_file: overridden_fields

import "package:material_ui/material_ui.dart";

/// A Flutter [TextTheme] whose styles are all non-null, narrowing the
/// nullable [TextTheme] fields to the styles Prego always defines.
class const GuaranteedTextTheme({
  @override required final TextStyle displayLarge,
  @override required final TextStyle displayMedium,
  @override required final TextStyle displaySmall,
  @override required final TextStyle headlineLarge,
  @override required final TextStyle headlineMedium,
  @override required final TextStyle headlineSmall,
  @override required final TextStyle titleLarge,
  @override required final TextStyle titleMedium,
  @override required final TextStyle titleSmall,
  @override required final TextStyle labelLarge,
  @override required final TextStyle labelMedium,
  @override required final TextStyle labelSmall,
  @override required final TextStyle bodyLarge,
  @override required final TextStyle bodyMedium,
  @override required final TextStyle bodySmall,
}) extends TextTheme;

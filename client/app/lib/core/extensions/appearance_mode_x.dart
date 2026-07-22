import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Maps the surface-neutral [AppearanceMode] onto Flutter's [ThemeMode] at the
/// shell boundary, so shared logic never has to depend on Flutter.
extension AppearanceModeX on AppearanceMode {
  ThemeMode get themeMode => switch (this) {
    AppearanceMode.light => ThemeMode.light,
    AppearanceMode.dark => ThemeMode.dark,
    AppearanceMode.system => ThemeMode.system,
  };
}

import "package:flutter/material.dart";

/// Cross-platform monospace fallbacks, in priority order, used when the
/// platform "monospace" alias is unavailable.
const _monospaceFontFallback = ["Menlo", "Roboto Mono", "Courier New"];

extension TextStyleMonospace on TextStyle {
  /// Returns a copy of this style rendered in the platform monospace font,
  /// with sensible cross-platform fallbacks. Use this instead of setting
  /// `fontFamily: "monospace"` directly so the font choice stays in one place.
  TextStyle get monospace => copyWith(
    fontFamily: "monospace",
    fontFamilyFallback: _monospaceFontFallback,
  );
}

import 'package:flutter/material.dart';

extension ColorExtensions on Color {
  /// Returns a new color with its alpha multiplied by [opacity].
  ///
  /// Unlike [withValues] which replaces the alpha channel, this preserves the
  /// existing transparency by multiplying: `result.alpha = current.alpha * opacity`.
  /// For example, a color at 80% alpha with `withMultipliedOpacity(0.5)` becomes 40%.
  ///
  /// Prefer this over wrapping widgets in [Opacity] to avoid compositing layers.
  Color withMultipliedOpacity(double opacity) => withValues(alpha: a * opacity);
}

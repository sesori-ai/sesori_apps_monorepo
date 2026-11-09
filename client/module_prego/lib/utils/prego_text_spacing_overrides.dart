import "package:material_ui/material_ui.dart";

/// [style] with the accessibility line-height, letter-spacing and word-spacing
/// overrides of the nearest [MediaQuery] on top, as [Text] applies them to
/// every span it draws. Code that measures text for a [Text] needs them to
/// measure what is drawn.
TextStyle withTextSpacingOverrides({required BuildContext context, required TextStyle style}) {
  final lineHeightScaleFactor = MediaQuery.maybeLineHeightScaleFactorOverrideOf(context);
  final letterSpacing = MediaQuery.maybeLetterSpacingOverrideOf(context);
  final wordSpacing = MediaQuery.maybeWordSpacingOverrideOf(context);
  if (lineHeightScaleFactor == null && letterSpacing == null && wordSpacing == null) return style;
  return style.merge(TextStyle(height: lineHeightScaleFactor, letterSpacing: letterSpacing, wordSpacing: wordSpacing));
}

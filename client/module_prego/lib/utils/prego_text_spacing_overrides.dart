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

/// [style] resolved as a [Text] here resolves its own: on top of the
/// [DefaultTextStyle], bold when the platform asks for bold text, and with the
/// spacing overrides of [withTextSpacingOverrides]. Code that measures text for
/// a [Text] needs it to measure what is drawn.
TextStyle resolveTextStyle({required BuildContext context, required TextStyle? style}) {
  var resolved = DefaultTextStyle.of(context).style.merge(style);
  if (MediaQuery.boldTextOf(context)) {
    resolved = resolved.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  return withTextSpacingOverrides(context: context, style: resolved);
}

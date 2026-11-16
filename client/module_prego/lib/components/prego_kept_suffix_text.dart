import "package:material_ui/material_ui.dart";

/// One line of text that, when it ends with [keptSuffix] and does not fit,
/// cuts the text before the suffix instead of at its end, so the suffix stays
/// whole: "Math Utilities… (fork)" rather than "Math Utilities Summa…".
///
/// Text that does not end with [keptSuffix] renders as the plain [Text] it is.
/// It is a [Text] so that `find.text` and other code reading a label see the
/// whole string, and screen readers always get the whole [text].
class const PregoKeptSuffixText({
  super.key,
  required final String text,

  /// Kept whole at the end of [text]. Null cuts [text] at its end, as [Text]
  /// does.
  required final String? keptSuffix,
  required TextStyle? style,

  /// [TextAlign.center] centres a cut line; any other value starts it at the
  /// leading edge.
  TextAlign? textAlign,
  bool? softWrap,

  /// How the text before [keptSuffix] is cut.
  TextOverflow overflow = TextOverflow.ellipsis,
}) extends Text {
  this
    : super(text, style: style, textAlign: textAlign, softWrap: softWrap, overflow: overflow, maxLines: 1);

  /// [text] split before [keptSuffix], or null when it does not end with it.
  /// For lines that compose their own parts, such as highlighted matches.
  static ({String base, String suffix})? split({required String text, required String? keptSuffix}) {
    if (keptSuffix == null || !text.endsWith(keptSuffix)) return null;
    return (base: text.substring(0, text.length - keptSuffix.length), suffix: keptSuffix);
  }

  @override
  Widget build(BuildContext context) {
    final parts = split(text: text, keptSuffix: keptSuffix);
    if (parts == null) return super.build(context);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: textAlign == TextAlign.center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Text(parts.base, style: style, maxLines: 1, softWrap: softWrap, overflow: overflow),
          ),
          Text(parts.suffix, style: style, maxLines: 1, softWrap: false),
        ],
      ),
    );
  }
}

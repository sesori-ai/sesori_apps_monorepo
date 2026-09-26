import "package:markdown/markdown.dart" as md;

/// The words [markdown] renders to, with its syntax resolved by the parser:
/// emphasis markers and backticks are gone, a link reads as its label, and
/// blocks are separated by a single newline.
///
/// This is what a reader should hear where a widget shows rendered Markdown but
/// can only carry a plain string, such as a semantics label or a one-line
/// preview. Parsing, rather than a pattern over the source, is the only way to
/// tell a marker from a character the prompt meant literally.
///
/// An image contributes nothing: it has no words. Returns an empty string when
/// nothing in [markdown] renders as text, which the caller decides how to
/// present.
String markdownPlainText({required String markdown}) {
  // The result is shown as text, not as HTML, so character references are
  // decoded instead of re-escaped.
  final nodes = md.Document(encodeHtml: false).parse(markdown);
  final blocks = <String>[];
  for (final node in nodes) {
    final buffer = StringBuffer();
    _writeText(node: node, buffer: buffer);
    final text = buffer.toString().trim();
    if (text.isNotEmpty) blocks.add(text);
  }
  return blocks.join("\n");
}

void _writeText({required md.Node node, required StringBuffer buffer}) {
  switch (node) {
    case md.Text():
      buffer.write(node.text);
    case md.Element(tag: "img"):
      return;
    case md.Element():
      for (final child in node.children ?? const <md.Node>[]) {
        _writeText(node: child, buffer: buffer);
      }
    default:
      return;
  }
}

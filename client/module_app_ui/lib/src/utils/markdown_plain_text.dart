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
/// [nameImage] gives an image its words, from the alt text the Markdown carries
/// for it, if any. Pass the renderer's own naming where the result has to agree
/// with what is on screen, or null where an image contributes nothing, as in a
/// row that shows words beside a label and never a picture.
///
/// Returns an empty string when nothing in [markdown] renders as text, which the
/// caller decides how to present.
String markdownPlainText({
  required String markdown,
  required String Function({required String? altText})? nameImage,
}) {
  // The renderer's own defaults: the same extensions, so a table or a struck
  // word reads as its words here too and not as its source, and no HTML
  // escaping, because the result is shown as text rather than as HTML.
  final nodes = md.Document(encodeHtml: false, extensionSet: md.ExtensionSet.gitHubFlavored).parse(markdown);
  final buffer = StringBuffer();
  for (final node in nodes) {
    _writeText(node: node, buffer: buffer, nameImage: nameImage);
  }
  return buffer.toString().trim();
}

void _writeText({
  required md.Node node,
  required StringBuffer buffer,
  required String Function({required String? altText})? nameImage,
}) {
  switch (node) {
    case md.Text():
      buffer.write(node.text);
    case md.Element(tag: "img"):
      // The parser puts the alt text in the attribute, not in the children.
      buffer.write(nameImage?.call(altText: node.attributes["alt"]) ?? "");
    case md.Element():
      // A block the renderer gives a line of its own starts one here too, so
      // two list items or table cells do not run into one word. Emphasis and
      // the like are not blocks, so `un**bold**ed` stays one word.
      if (_lineTags.contains(node.tag)) buffer.write("\n");
      for (final child in node.children ?? const <md.Node>[]) {
        _writeText(node: child, buffer: buffer, nameImage: nameImage);
      }
    default:
      return;
  }
}

const _lineTags = {"p", "li", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre", "th", "td"};

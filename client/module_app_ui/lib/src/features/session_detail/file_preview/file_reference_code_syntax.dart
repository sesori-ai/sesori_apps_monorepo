import "package:markdown/markdown.dart" as md;
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Inline code that reads as a file path, such as `lib/main.dart:12`, becomes a
/// link to that path, so a tap opens the file. Other inline code renders as
/// usual. Code that is already a link's text keeps the link it is in.
class FileReferenceCodeSyntax() extends md.CodeSyntax {
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final code = match[2]?.trim();
    if (code == null || !looksLikeFileReference(raw: code) || _isLinkText(parser: parser, match: match)) {
      return super.onMatch(parser, match);
    }
    parser.addNode(md.Element("a", [md.Element.text("code", code)])..attributes["href"] = code);
    return true;
  }

  /// Whether the span is the whole text of a Markdown link, as in
  /// `` [`lib/a.dart`](https://…) ``.
  bool _isLinkText({required md.InlineParser parser, required Match match}) =>
      match.start > 0 && parser.source.startsWith("[", match.start - 1) && parser.source.startsWith("](", match.end);
}

/// Inline syntaxes for chat text parts and user messages.
final List<md.InlineSyntax> sessionMarkdownInlineSyntaxes = [FileReferenceCodeSyntax()];

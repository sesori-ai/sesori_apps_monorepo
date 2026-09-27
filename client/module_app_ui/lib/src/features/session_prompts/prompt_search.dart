import "dart:math" as math;

/// How many characters a search excerpt keeps before its match; the rest of
/// the line is the text after it, as far as the row's width allows.
const int _kExcerptLead = 24;
const int _kExcerptTrail = 80;

final _whitespace = RegExp(r"\s+");

/// Finds [query] in a prompt's whole text, ignoring case; null when [query]
/// holds nothing but whitespace, which searches for nothing.
RegExp? promptSearchPattern({required String query}) {
  final trimmed = query.trim();
  return trimmed.isEmpty ? null : RegExp(RegExp.escape(trimmed), caseSensitive: false);
}

/// A search [match] in a prompt's text, with the words around it on one line.
typedef PromptExcerpt = ({String before, String match, String after});

/// The window of [text] around [match], clipped at the text's ends; an
/// ellipsis marks text cut before it.
PromptExcerpt promptExcerpt({required String text, required Match match}) {
  final start = math.max(0, match.start - _kExcerptLead);
  final end = math.min(text.length, match.end + _kExcerptTrail);
  String oneLine(String part) => part.replaceAll(_whitespace, " ");
  return (
    before: "${start > 0 ? "…" : ""}${oneLine(text.substring(start, match.start)).trimLeft()}",
    match: oneLine(text.substring(match.start, match.end)),
    after: oneLine(text.substring(match.end, end)),
  );
}

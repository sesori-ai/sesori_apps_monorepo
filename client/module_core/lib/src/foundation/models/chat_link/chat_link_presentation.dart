import "package:path/path.dart" as p;

import "../file_reference/file_reference.dart";

/// How a chat message shows a link: which icon leads it and what it reads.
///
/// Presentation only. Tapping, tooltips and copying always use the link's
/// original target.
sealed class const ChatLinkPresentation() {
  /// The text shown after the icon.
  String get label;
}

/// A file reference: a type badge or a plain file icon, then the file name and
/// the line it names, if any.
final class const ChatFileLinkPresentation({
  required final String fileName,
  required final int? line,
  required final FileTypeBadge? badge,
}) extends ChatLinkPresentation {
  @override
  String get label => line == null ? fileName : "$fileName (line $line)";
}

/// A link to github.com, led by the GitHub mark.
final class const ChatGitHubLinkPresentation({@override required final String label}) extends ChatLinkPresentation;

/// Any other web link, led by a globe.
final class const ChatWebLinkPresentation({@override required final String label}) extends ChatLinkPresentation;

/// A link with no recognised destination, such as `mailto:`, shown as its own
/// text with no icon.
final class const ChatPlainLinkPresentation({@override required final String label}) extends ChatLinkPresentation;

/// The common languages a file link marks with a text badge instead of the
/// plain file icon.
enum FileTypeBadge({required final String label}) {
  dart(label: "DART"),
  javaScript(label: "JS"),
  jsx(label: "JSX"),
  typeScript(label: "TS"),
  tsx(label: "TSX"),
  python(label: "PY"),
  rust(label: "RS"),
  go(label: "GO"),
  swift(label: "SWIFT"),
  kotlin(label: "KT"),
  java(label: "JAVA"),
  markdown(label: "MD"),
  json(label: "JSON"),
  yaml(label: "YAML"),
  shell(label: "SH");

  static FileTypeBadge? forFileName({required String fileName}) => switch (p.posix.extension(fileName).toLowerCase()) {
    ".dart" => dart,
    ".js" => javaScript,
    ".jsx" => jsx,
    ".ts" => typeScript,
    ".tsx" => tsx,
    ".py" => python,
    ".rs" => rust,
    ".go" => go,
    ".swift" => swift,
    ".kt" => kotlin,
    ".java" => java,
    ".md" => markdown,
    ".json" => json,
    ".yaml" || ".yml" => yaml,
    ".sh" => shell,
    _ => null,
  };
}

/// Builds the presentation of a chat link from its [href] and the [text] the
/// message wrote for it. Labels are built locally; nothing is fetched.
///
/// - A file reference shows its file name and line, whatever its text says.
/// - A bare web URL, whose text is the URL itself, gets a short label: a
///   GitHub pull request, issue or commit names its repository and number or
///   short hash, and any other URL shows its host.
/// - A web link with its own text keeps that text.
ChatLinkPresentation presentChatLink({required String href, required String text}) {
  final uri = Uri.tryParse(href);
  final scheme = uri?.scheme.toLowerCase();
  if (uri != null && (scheme == "http" || scheme == "https") && uri.host.isNotEmpty) {
    return _presentWebLink(
      uri: uri,
      isBare: _isBareUrl(href: href, text: text),
      text: text,
    );
  }
  final file = recognizeFilePath(raw: href);
  if (file != null) {
    final fileName = recognizedFileName(path: file.path);
    return ChatFileLinkPresentation(
      fileName: fileName,
      line: file.line,
      badge: FileTypeBadge.forFileName(fileName: fileName),
    );
  }
  return ChatPlainLinkPresentation(label: text);
}

/// Whether [text] is the URL itself, as an autolink or a pasted URL writes it,
/// with or without its scheme.
bool _isBareUrl({required String href, required String text}) {
  final written = text.trim();
  return written == href || written == href.replaceFirst(RegExp("^https?://", caseSensitive: false), "");
}

ChatLinkPresentation _presentWebLink({required Uri uri, required bool isBare, required String text}) {
  final host = uri.host.toLowerCase();
  if (host == "github.com" || host == "www.github.com") {
    return ChatGitHubLinkPresentation(label: isBare ? (_gitHubLabel(uri: uri) ?? host) : text);
  }
  return ChatWebLinkPresentation(label: isBare ? host : text);
}

/// `<repo> PR #n`, `<repo> #n` or `<repo> @<short sha>` for a GitHub pull
/// request, issue or commit URL; `null` for any other GitHub page.
String? _gitHubLabel({required Uri uri}) {
  final segments = uri.pathSegments;
  if (segments.length < 4) return null;
  final repo = segments[1];
  final id = segments[3];
  return switch (segments[2]) {
    "pull" when _isNumber(text: id) => "$repo PR #$id",
    "issues" when _isNumber(text: id) => "$repo #$id",
    "commit" when RegExp(r"^[0-9a-fA-F]{7,40}$").hasMatch(id) => "$repo @${id.substring(0, 7)}",
    _ => null,
  };
}

bool _isNumber({required String text}) => RegExp(r"^\d+$").hasMatch(text);

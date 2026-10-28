import "package:meta/meta.dart";
import "package:path/path.dart" as p;

/// A file a chat message points at, resolved to an absolute path on the
/// bridge's computer, with the line the reference named, if any.
@immutable
final class const FileReference({
  required final String absolutePath,
  required final int? line,
}) {
  /// The last segment of [absolutePath].
  String get fileName => p.posix.basename(absolutePath);

  @override
  bool operator ==(Object other) => other is FileReference && other.absolutePath == absolutePath && other.line == line;

  @override
  int get hashCode => Object.hash(absolutePath, line);

  @override
  String toString() => "FileReference($absolutePath, line: $line)";
}

/// A `scheme:` prefix, which marks a URL rather than a path.
final _scheme = RegExp(r"^[A-Za-z][A-Za-z0-9+.\-]*:");

/// An optional `:line` or `:line:col` suffix.
final _location = RegExp(r"^(.+?)(?::(\d+)(?::\d+)?)?$");

/// A file name ending in an extension that contains a letter, so `v1.2/3.4`
/// and version-like text are not files.
final _extension = RegExp(r"\.[A-Za-z0-9_\-]*[A-Za-z][A-Za-z0-9_\-]*$");

/// Characters that never appear in a path a message means to point at.
final _excluded = RegExp(r"""[\s*?<>|"'`~]""");

typedef _Recognized = ({String path, int? line});

/// Recognises [raw] as a path to a file: a `file://` URI, an absolute path, or
/// a relative path, each containing a `/` and ending in a file extension, with
/// an optional `:line` or `:line:col` suffix. Returns `null` for anything else,
/// including URLs with any other scheme.
_Recognized? _recognize({required String raw}) {
  var text = raw.trim();
  if (text.toLowerCase().startsWith("file://")) {
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isNotEmpty) return null;
    text = uri.path;
  } else if (_scheme.hasMatch(text)) {
    return null;
  }
  final match = _location.firstMatch(text);
  if (match == null) return null;
  final path = match.group(1);
  if (path == null || !path.contains("/") || _excluded.hasMatch(path)) return null;
  if (!_extension.hasMatch(p.posix.basename(path))) return null;
  final lineText = match.group(2);
  final line = lineText == null ? null : int.tryParse(lineText);
  return (path: path, line: line == null || line < 1 ? null : line);
}

/// Whether [raw] reads as a reference to a file, before it is resolved
/// against a session's directory.
bool looksLikeFileReference({required String raw}) => _recognize(raw: raw) != null;

/// Parses [raw] as a [FileReference], resolving a relative path against
/// [sessionDirectory]. Returns `null` when [raw] is not a file reference.
FileReference? parseFileReference({required String raw, required String sessionDirectory}) {
  final recognized = _recognize(raw: raw);
  if (recognized == null) return null;
  final path = recognized.path;
  final absolutePath = p.posix.normalize(
    p.posix.isAbsolute(path) ? path : p.posix.join(sessionDirectory, path),
  );
  if (!p.posix.isAbsolute(absolutePath)) return null;
  return FileReference(absolutePath: absolutePath, line: recognized.line);
}

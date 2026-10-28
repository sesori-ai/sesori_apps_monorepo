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
  String get fileName => _pathContextFor(path: absolutePath).basename(absolutePath);

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

/// A Windows drive path, such as `C:\src\a.cs` or `C:/src/a.cs`.
final _windowsDrive = RegExp(r"^[A-Za-z]:[\\/]");

/// A path separator on either POSIX or Windows.
final _separator = RegExp(r"[\\/]");

/// Characters that never appear in a path a message means to point at.
final _excluded = RegExp(r"""[\s*?<>|"'`~]""");

typedef _Recognized = ({String path, int? line});

/// Recognises [raw] as a path to a file: a local `file://` URI, an absolute
/// POSIX or Windows path, or a relative path, each containing a separator and
/// ending in a file extension, with an optional `:line` or `:line:col` suffix.
/// Returns `null` for anything else, including URLs with any other scheme.
_Recognized? _recognize({required String raw}) {
  var text = raw.trim();
  final isUri = text.toLowerCase().startsWith("file://");
  if (isUri) {
    final uri = Uri.tryParse(text);
    if (uri == null || (uri.host.isNotEmpty && uri.host != "localhost")) return null;
    text = uri.path;
    // `file:///C:/a.cs` carries a Windows drive after the leading slash.
    if (text.startsWith("/") && _windowsDrive.hasMatch(text.substring(1))) text = text.substring(1);
  } else if (_scheme.hasMatch(text) && !_windowsDrive.hasMatch(text)) {
    return null;
  }
  final match = _location.firstMatch(text);
  if (match == null) return null;
  final encoded = match.group(1);
  if (encoded == null || !encoded.contains(_separator) || _excluded.hasMatch(encoded)) return null;
  final path = isUri ? Uri.decodeComponent(encoded) : encoded;
  if (!_extension.hasMatch(path.split(_separator).last)) return null;
  final lineText = match.group(2);
  final line = lineText == null ? null : int.tryParse(lineText);
  return (path: path, line: line == null || line < 1 ? null : line);
}

/// Windows path semantics for a path on a drive, POSIX for anything else.
p.Context _pathContextFor({required String path}) => _windowsDrive.hasMatch(path) ? p.windows : p.posix;

/// Whether [raw] reads as a reference to a file, before it is resolved
/// against a session's directory.
bool looksLikeFileReference({required String raw}) => _recognize(raw: raw) != null;

/// Parses [raw] as a [FileReference], resolving a relative path against
/// [sessionDirectory], with the path semantics of that directory's host.
/// Returns `null` when [raw] is not a file reference.
FileReference? parseFileReference({required String raw, required String sessionDirectory}) {
  final recognized = _recognize(raw: raw);
  if (recognized == null) return null;
  final path = recognized.path;
  final context = _pathContextFor(path: sessionDirectory);
  final absolutePath = context.normalize(context.isAbsolute(path) ? path : context.join(sessionDirectory, path));
  if (!context.isAbsolute(absolutePath)) return null;
  return FileReference(absolutePath: absolutePath, line: recognized.line);
}

import "package:path/path.dart" as p;

import "project.dart";
import "project_kind.dart";

/// The name [project] goes by of its own: its stored name, else its
/// directory's. Null for the bridge's project of folderless sessions, whatever
/// an older app renamed it to, and for a path with no last segment: surfaces
/// show their own words for those.
String? projectOwnName({required ProjectSummary project}) {
  if (project.kind == ProjectKind.scratch) return null;
  final basename = hostPathBasename(path: project.path);
  return project.name ?? (basename.isEmpty ? null : basename);
}

/// The last segment of a bridge host [path], whichever separator it uses. A
/// Windows drive root such as `C:\` keeps its full path, not a bare `C:`.
String hostPathBasename({required String path}) {
  // Bridges run on macOS, Linux or Windows, so both separator styles arrive.
  final posix = path.replaceAll(r"\", "/");
  return RegExp(r"^[A-Za-z]:/?$").hasMatch(posix) ? path : p.posix.basename(posix);
}

import "package:sesori_shared/sesori_shared.dart";

/// Each project's path by id, shortened to the trailing folders that tell it
/// apart from projects sharing its [nameOf].
///
/// A row is far too narrow for a real path, and the tail is the part that
/// differs, so the head goes: two folders at least, one more while a
/// same-named project still ends the same way. A cut path starts with "…/";
/// one that grows whole keeps its root ("/" or "C:").
Map<String, String> projectPathLabels({
  required List<ProjectSummary> projects,
  required String Function(ProjectSummary project) nameOf,
}) {
  final entries = [
    for (final project in projects) (project: project, name: nameOf(project), segments: _segments(project.path)),
  ];
  // ponytail: compares every pair, fine for a project list; group by name if lists reach thousands.
  return {
    for (final entry in entries)
      entry.project.id: _label(
        path: entry.project.path,
        segments: entry.segments,
        rivals: [
          for (final other in entries)
            if (other.project.id != entry.project.id && other.name == entry.name) other.segments,
        ],
      ),
  };
}

const int _minSegments = 2;

String _label({required String path, required List<String> segments, required List<List<String>> rivals}) {
  var count = _minSegments;
  while (count < segments.length && rivals.any((rival) => _sameTail(a: rival, b: segments, count: count))) {
    count++;
  }
  if (count >= segments.length) return _toPosix(path);
  return "…/${segments.sublist(segments.length - count).join("/")}";
}

bool _sameTail({required List<String> a, required List<String> b, required int count}) {
  if (a.length < count || b.length < count) return false;
  for (var i = 1; i <= count; i++) {
    if (a[a.length - i] != b[b.length - i]) return false;
  }
  return true;
}

List<String> _segments(String path) => _toPosix(path).split("/").where((s) => s.isNotEmpty).toList();

/// Bridges run on macOS, Linux or Windows, so both separator styles arrive.
String _toPosix(String path) => path.replaceAll(r"\", "/");

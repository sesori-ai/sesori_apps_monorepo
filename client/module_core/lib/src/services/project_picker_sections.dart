import "package:sesori_shared/sesori_shared.dart";

const int _recentCount = 3;

/// Below this, a recent section would leave almost nothing to sort below it.
const int _sectionsMinProjects = 6;

/// Splits a project picker's list, ordered most recent first, into the most
/// recent projects and the rest by session count, ties staying most recent
/// first. Null for a list too short to need it.
({List<ProjectSummary> recent, List<ProjectSummary> bySessionCount})? projectPickerSections({
  required List<ProjectSummary> projects,
}) {
  if (projects.length < _sectionsMinProjects) return null;
  // The index keeps ties in order, which sort alone does not promise.
  final rest = projects.skip(_recentCount).indexed.toList()
    ..sort((a, b) {
      final byCount = b.$2.sessionCount.compareTo(a.$2.sessionCount);
      return byCount != 0 ? byCount : a.$1.compareTo(b.$1);
    });
  return (
    recent: projects.take(_recentCount).toList(),
    bySessionCount: [for (final (_, project) in rest) project],
  );
}

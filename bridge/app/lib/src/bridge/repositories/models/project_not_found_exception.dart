/// Thrown when an operation references a project the bridge has not recorded.
///
/// Project identifiers are opaque handles, not directories. Callers must not
/// infer a filesystem path from an unknown id — a project becomes known only
/// when the plugin lists it or the user opens it by path.
class const ProjectNotFoundException({required this.projectId}) implements Exception {
  final String projectId;

  @override
  String toString() => "Project not found: $projectId";
}

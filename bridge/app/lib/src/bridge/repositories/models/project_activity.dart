import "package:meta/meta.dart";

/// Persisted project activity timestamps.
@immutable
class ProjectActivity {
  const ProjectActivity({required this.createdAt, required this.updatedAt});

  final int createdAt;
  final int updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectActivity && createdAt == other.createdAt && updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(createdAt, updatedAt);
}

@immutable
class ProjectActivityChange {
  const ProjectActivityChange({required this.projectId, required this.updatedAt});

  final String projectId;
  final int updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectActivityChange && projectId == other.projectId && updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(projectId, updatedAt);
}

@immutable
class StoredProjectActivity {
  const StoredProjectActivity({required this.projectId, required this.activity});

  final String projectId;
  final ProjectActivity activity;
}

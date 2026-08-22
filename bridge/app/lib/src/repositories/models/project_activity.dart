import "package:meta/meta.dart";

/// Persisted project activity timestamps.
@immutable
class const ProjectActivity({required final int createdAt, required final int updatedAt}) {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectActivity && createdAt == other.createdAt && updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(createdAt, updatedAt);
}

@immutable
class const ProjectActivityChange({required final String projectId, required final int updatedAt}) {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectActivityChange && projectId == other.projectId && updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(projectId, updatedAt);
}

@immutable
class const StoredProjectActivity({required final String projectId, required final ProjectActivity activity});

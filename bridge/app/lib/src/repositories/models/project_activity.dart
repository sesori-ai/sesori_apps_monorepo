import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectTime;

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
class const StoredProjectActivity({required final String projectId, required final ProjectTime activity});

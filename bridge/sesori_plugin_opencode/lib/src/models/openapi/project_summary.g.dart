// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';

@immutable
class ProjectSummary {
  const ProjectSummary({
    this.id = '',
    this.name,
    this.worktree = '',
  });

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    return ProjectSummary(
      id: (json["id"] ?? '') as String,
      name: json["name"] as String?,
      worktree: (json["worktree"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": ?name,
      "worktree": worktree,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProjectSummary copyWith({
    String? id,
    String? name,
    String? worktree,
  }) {
    return ProjectSummary(
      id: id ?? this.id,
      name: name ?? this.name,
      worktree: worktree ?? this.worktree,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectSummary &&
          other.id == id &&
          other.name == name &&
          other.worktree == worktree);

  @override
  int get hashCode => Object.hash(id, name, worktree);

  final String id;
  final String? name;
  final String worktree;
}

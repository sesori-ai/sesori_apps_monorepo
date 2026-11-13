// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';

@immutable
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.worktree,
  });

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    return ProjectSummary(
      id: json["id"] as String,
      name: json["name"] as String?,
      worktree: json["worktree"] as String,
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

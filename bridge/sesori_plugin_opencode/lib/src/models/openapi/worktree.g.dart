// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class Worktree {
  const Worktree({
    this.name = '',
    this.branch,
    this.directory = '',
  });

  factory Worktree.fromJson(Map<String, dynamic> json) {
    return Worktree(
      name: (json["name"] ?? '') as String,
      branch: json["branch"] as String?,
      directory: (json["directory"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "branch": ?branch,
      "directory": directory,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Worktree copyWith({
    String? name,
    String? branch,
    String? directory,
  }) {
    return Worktree(
      name: name ?? this.name,
      branch: branch ?? this.branch,
      directory: directory ?? this.directory,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Worktree &&
          other.name == name &&
          other.branch == branch &&
          other.directory == directory);

  @override
  int get hashCode => Object.hash(name, branch, directory);

  final String name;
  final String? branch;
  final String directory;
}

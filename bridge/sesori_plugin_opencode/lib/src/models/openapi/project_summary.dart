// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.182046Z


class ProjectSummary {
  const ProjectSummary({
    required this.id,
    this.name,
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

  final String id;
  final String? name;
  final String worktree;
}

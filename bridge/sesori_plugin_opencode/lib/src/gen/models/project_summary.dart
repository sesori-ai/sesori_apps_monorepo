// GENERATED FILE - DO NOT EDIT BY HAND


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
      "name": name,
      "worktree": worktree,
    };
  }

  final String id;
  final String? name;
  final String worktree;
}

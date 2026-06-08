// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:40.015009Z


class Worktree {
  const Worktree({
    required this.name,
    this.branch,
    required this.directory,
  });

  factory Worktree.fromJson(Map<String, dynamic> json) {
    return Worktree(
      name: json["name"] as String,
      branch: json["branch"] as String?,
      directory: json["directory"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "branch": ?branch,
      "directory": directory,
    };
  }

  final String name;
  final String? branch;
  final String directory;
}

// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.624768Z


class Project {
  const Project({
    required this.id,
    required this.worktree,
    this.vcs,
    this.name,
    this.icon,
    this.commands,
    required this.time,
    required this.sandboxes,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json["id"] as String,
      worktree: json["worktree"] as String,
      vcs: json["vcs"] as String?,
      name: json["name"] as String?,
      icon: json["icon"] as Map<String, dynamic>?,
      commands: json["commands"] as Map<String, dynamic>?,
      time: json["time"] as Map<String, dynamic>,
      sandboxes: (json["sandboxes"] as List<dynamic>).cast<String>(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "worktree": worktree,
      "vcs": ?vcs,
      "name": ?name,
      "icon": ?icon,
      "commands": ?commands,
      "time": time,
      "sandboxes": sandboxes,
    };
  }

  final String id;
  final String worktree;
  final String? vcs;
  final String? name;
  final Map<String, dynamic>? icon;
  final Map<String, dynamic>? commands;
  final Map<String, dynamic> time;
  final List<String> sandboxes;
}

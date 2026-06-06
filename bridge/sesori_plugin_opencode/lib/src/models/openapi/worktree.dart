// GENERATED FILE - DO NOT EDIT BY HAND


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
      "branch": branch,
      "directory": directory,
    };
  }

  final String name;
  final String? branch;
  final String directory;
}

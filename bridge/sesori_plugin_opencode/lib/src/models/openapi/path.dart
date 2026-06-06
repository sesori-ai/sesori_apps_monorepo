// GENERATED FILE - DO NOT EDIT BY HAND


class Path {
  const Path({
    required this.home,
    required this.state,
    required this.config,
    required this.worktree,
    required this.directory,
  });

  factory Path.fromJson(Map<String, dynamic> json) {
    return Path(
      home: json["home"] as String,
      state: json["state"] as String,
      config: json["config"] as String,
      worktree: json["worktree"] as String,
      directory: json["directory"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "home": home,
      "state": state,
      "config": config,
      "worktree": worktree,
      "directory": directory,
    };
  }

  final String home;
  final String state;
  final String config;
  final String worktree;
  final String directory;
}

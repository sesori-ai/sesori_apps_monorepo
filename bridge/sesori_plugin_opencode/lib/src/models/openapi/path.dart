// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.945081Z

import 'package:meta/meta.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Path &&
          other.home == home &&
          other.state == state &&
          other.config == config &&
          other.worktree == worktree &&
          other.directory == directory);

  @override
  int get hashCode => Object.hash(home, state, config, worktree, directory);

  final String home;
  final String state;
  final String config;
  final String worktree;
  final String directory;
}

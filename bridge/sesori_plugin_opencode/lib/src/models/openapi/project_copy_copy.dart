// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.950289Z

import 'package:meta/meta.dart';

@immutable
class ProjectCopyCopy {
  const ProjectCopyCopy({
    required this.directory,
  });

  factory ProjectCopyCopy.fromJson(Map<String, dynamic> json) {
    return ProjectCopyCopy(
      directory: json["directory"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectCopyCopy &&
          other.directory == directory);

  @override
  int get hashCode => directory.hashCode;

  final String directory;
}

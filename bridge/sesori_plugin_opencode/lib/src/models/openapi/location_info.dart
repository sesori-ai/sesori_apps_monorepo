// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.939184Z

import 'package:meta/meta.dart';

@immutable
class LocationInfo {
  const LocationInfo({
    required this.directory,
    this.workspaceID,
    required this.project,
  });

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      directory: json["directory"] as String,
      workspaceID: json["workspaceID"] as String?,
      project: json["project"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
      "workspaceID": ?workspaceID,
      "project": project,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationInfo &&
          other.directory == directory &&
          other.workspaceID == workspaceID &&
          other.project == project);

  @override
  int get hashCode => Object.hash(directory, workspaceID, project);

  final String directory;
  final String? workspaceID;
  final Map<String, dynamic> project;
}

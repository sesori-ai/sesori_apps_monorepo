// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.262387Z

import 'package:meta/meta.dart';

@immutable
class Workspace {
  const Workspace({
    required this.id,
    required this.type,
    required this.name,
    this.branch,
    this.directory,
    this.extra,
    required this.projectID,
    required this.timeUsed,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json["id"] as String,
      type: json["type"] as String,
      name: json["name"] as String,
      branch: json["branch"] as String?,
      directory: json["directory"] as String?,
      extra: json["extra"] as Object?,
      projectID: json["projectID"] as String,
      timeUsed: json["timeUsed"] as Object,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": type,
      "name": name,
      "branch": ?branch,
      "directory": ?directory,
      "extra": ?extra,
      "projectID": projectID,
      "timeUsed": timeUsed,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workspace &&
          other.id == id &&
          other.type == type &&
          other.name == name &&
          other.branch == branch &&
          other.directory == directory &&
          other.extra == extra &&
          other.projectID == projectID &&
          other.timeUsed == timeUsed);

  @override
  int get hashCode => Object.hash(id, type, name, branch, directory, extra, projectID, timeUsed);

  final String id;
  final String type;
  final String name;
  final String? branch;
  final String? directory;
  final Object? extra;
  final String projectID;
  final Object timeUsed;
}

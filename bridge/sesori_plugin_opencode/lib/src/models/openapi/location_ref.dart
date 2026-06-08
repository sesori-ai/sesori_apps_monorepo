// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.228955Z

import 'package:meta/meta.dart';

@immutable
class LocationRef {
  const LocationRef({
    required this.directory,
    this.workspaceID,
  });

  factory LocationRef.fromJson(Map<String, dynamic> json) {
    return LocationRef(
      directory: json["directory"] as String,
      workspaceID: json["workspaceID"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
      "workspaceID": ?workspaceID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationRef &&
          other.directory == directory &&
          other.workspaceID == workspaceID);

  @override
  int get hashCode => Object.hash(directory, workspaceID);

  final String directory;
  final String? workspaceID;
}

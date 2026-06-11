// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class GlobalEvent {
  const GlobalEvent({
    required this.directory,
    this.project,
    this.workspace,
    required this.payload,
  });

  factory GlobalEvent.fromJson(Map<String, dynamic> json) {
    return GlobalEvent(
      directory: json["directory"] as String,
      project: json["project"] as String?,
      workspace: json["workspace"] as String?,
      payload: json["payload"] as Object,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
      "project": ?project,
      "workspace": ?workspace,
      "payload": payload,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalEvent &&
          other.directory == directory &&
          other.project == project &&
          other.workspace == workspace &&
          const DeepCollectionEquality().equals(other.payload, payload));

  @override
  int get hashCode => Object.hash(directory, project, workspace, const DeepCollectionEquality().hash(payload));

  final String directory;
  final String? project;
  final String? workspace;
  final Object payload;
}

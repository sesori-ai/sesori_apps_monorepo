// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventProjectDirectoriesUpdated implements Event {
  const EventProjectDirectoriesUpdated({
    required this.id,
    required this.properties,
  });

  factory EventProjectDirectoriesUpdated.fromJson(Map<String, dynamic> json) {
    return EventProjectDirectoriesUpdated(
      id: json["id"] as String,
      properties: EventProjectDirectoriesUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "project.directories.updated",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventProjectDirectoriesUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventProjectDirectoriesUpdatedProperties properties;
}

@immutable
class EventProjectDirectoriesUpdatedProperties {
  const EventProjectDirectoriesUpdatedProperties({
    required this.projectID,
  });

  factory EventProjectDirectoriesUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventProjectDirectoriesUpdatedProperties(
      projectID: json["projectID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "projectID": projectID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventProjectDirectoriesUpdatedProperties &&
          other.projectID == projectID);

  @override
  int get hashCode => projectID.hashCode;

  final String projectID;
}

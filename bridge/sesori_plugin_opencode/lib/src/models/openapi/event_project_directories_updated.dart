// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventProjectDirectoriesUpdated implements Event {
  const EventProjectDirectoriesUpdated({
    required this.id,
    required this.properties,
  });

  factory EventProjectDirectoriesUpdated.fromJson(Map<String, dynamic> json) {
    return EventProjectDirectoriesUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "project.directories.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventProjectUpdated implements Event {
  const EventProjectUpdated({
    required this.id,
    required this.properties,
  });

  factory EventProjectUpdated.fromJson(Map<String, dynamic> json) {
    return EventProjectUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "project.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionUpdated implements Event {
  const EventSessionUpdated({
    required this.id,
    required this.properties,
  });

  factory EventSessionUpdated.fromJson(Map<String, dynamic> json) {
    return EventSessionUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPtyUpdated implements Event {
  const EventPtyUpdated({
    required this.id,
    required this.properties,
  });

  factory EventPtyUpdated.fromJson(Map<String, dynamic> json) {
    return EventPtyUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "pty.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

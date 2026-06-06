// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPtyCreated implements Event {
  const EventPtyCreated({
    required this.id,
    required this.properties,
  });

  factory EventPtyCreated.fromJson(Map<String, dynamic> json) {
    return EventPtyCreated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "pty.created",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPtyExited implements Event {
  const EventPtyExited({
    required this.id,
    required this.properties,
  });

  factory EventPtyExited.fromJson(Map<String, dynamic> json) {
    return EventPtyExited(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "pty.exited",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

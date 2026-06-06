// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPtyDeleted implements Event {
  const EventPtyDeleted({
    required this.id,
    required this.properties,
  });

  factory EventPtyDeleted.fromJson(Map<String, dynamic> json) {
    return EventPtyDeleted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "pty.deleted",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextMoved implements Event {
  const EventSessionNextMoved({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextMoved.fromJson(Map<String, dynamic> json) {
    return EventSessionNextMoved(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.moved",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

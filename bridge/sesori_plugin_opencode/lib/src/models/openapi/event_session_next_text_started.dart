// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextTextStarted implements Event {
  const EventSessionNextTextStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextTextStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextTextStarted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.text.started",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

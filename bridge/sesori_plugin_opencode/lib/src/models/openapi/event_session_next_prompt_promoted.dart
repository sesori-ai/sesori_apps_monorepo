// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextPromptPromoted implements Event {
  const EventSessionNextPromptPromoted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextPromptPromoted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextPromptPromoted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.prompt.promoted",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

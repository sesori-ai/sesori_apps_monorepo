// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextPromptPromoted implements Event {
  const EventSessionNextPromptPromoted({
    required this.id,
    required this.type,
    required this.properties,
  });

  factory EventSessionNextPromptPromoted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextPromptPromoted(
      id: json["id"] as String,
      type: json["type"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": type,
      "properties": properties,
    };
  }

  final String id;
  final String type;
  final Map<String, dynamic> properties;
}

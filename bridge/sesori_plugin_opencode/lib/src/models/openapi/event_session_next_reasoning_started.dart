// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextReasoningStarted implements Event {
  const EventSessionNextReasoningStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextReasoningStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningStarted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.reasoning.started",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

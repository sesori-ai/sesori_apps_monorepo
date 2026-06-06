// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextReasoningEnded implements Event {
  const EventSessionNextReasoningEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextReasoningEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningEnded(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.reasoning.ended",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

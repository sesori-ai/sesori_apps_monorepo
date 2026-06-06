// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextReasoningDelta implements Event {
  const EventSessionNextReasoningDelta({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextReasoningDelta.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningDelta(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.reasoning.delta",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

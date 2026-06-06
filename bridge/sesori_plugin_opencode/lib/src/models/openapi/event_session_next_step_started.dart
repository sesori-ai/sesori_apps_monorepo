// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextStepStarted implements Event {
  const EventSessionNextStepStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextStepStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepStarted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.step.started",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

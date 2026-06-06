// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextStepFailed implements Event {
  const EventSessionNextStepFailed({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextStepFailed.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepFailed(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.step.failed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextStepEnded implements Event {
  const EventSessionNextStepEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextStepEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepEnded(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.step.ended",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

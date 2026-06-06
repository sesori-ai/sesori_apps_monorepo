// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextToolInputDelta implements Event {
  const EventSessionNextToolInputDelta({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolInputDelta.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolInputDelta(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.input.delta",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

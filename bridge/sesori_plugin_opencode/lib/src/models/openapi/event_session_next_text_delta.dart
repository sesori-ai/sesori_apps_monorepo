// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextTextDelta implements Event {
  const EventSessionNextTextDelta({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextTextDelta.fromJson(Map<String, dynamic> json) {
    return EventSessionNextTextDelta(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.text.delta",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

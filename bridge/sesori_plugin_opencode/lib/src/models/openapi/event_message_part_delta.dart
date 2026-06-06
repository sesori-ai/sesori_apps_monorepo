// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventMessagePartDelta implements Event {
  const EventMessagePartDelta({
    required this.id,
    required this.properties,
  });

  factory EventMessagePartDelta.fromJson(Map<String, dynamic> json) {
    return EventMessagePartDelta(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.part.delta",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

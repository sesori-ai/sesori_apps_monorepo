// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventMessagePartUpdated implements Event {
  const EventMessagePartUpdated({
    required this.id,
    required this.properties,
  });

  factory EventMessagePartUpdated.fromJson(Map<String, dynamic> json) {
    return EventMessagePartUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.part.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

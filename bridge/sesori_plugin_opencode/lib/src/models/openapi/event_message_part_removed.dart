// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventMessagePartRemoved implements Event {
  const EventMessagePartRemoved({
    required this.id,
    required this.properties,
  });

  factory EventMessagePartRemoved.fromJson(Map<String, dynamic> json) {
    return EventMessagePartRemoved(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.part.removed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

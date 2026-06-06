// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextInterruptRequested implements Event {
  const EventSessionNextInterruptRequested({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextInterruptRequested.fromJson(Map<String, dynamic> json) {
    return EventSessionNextInterruptRequested(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.interrupt.requested",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

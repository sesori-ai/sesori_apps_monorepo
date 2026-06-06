// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextRetried implements Event {
  const EventSessionNextRetried({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextRetried.fromJson(Map<String, dynamic> json) {
    return EventSessionNextRetried(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.retried",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

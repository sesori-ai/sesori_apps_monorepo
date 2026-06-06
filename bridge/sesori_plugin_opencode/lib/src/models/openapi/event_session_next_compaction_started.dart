// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextCompactionStarted implements Event {
  const EventSessionNextCompactionStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextCompactionStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionStarted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.compaction.started",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

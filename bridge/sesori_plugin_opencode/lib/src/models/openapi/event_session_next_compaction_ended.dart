// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextCompactionEnded implements Event {
  const EventSessionNextCompactionEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextCompactionEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionEnded(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.compaction.ended",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

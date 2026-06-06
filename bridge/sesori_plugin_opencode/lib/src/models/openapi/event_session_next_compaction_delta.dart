// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextCompactionDelta implements Event {
  const EventSessionNextCompactionDelta({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextCompactionDelta.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionDelta(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.compaction.delta",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.888922Z

import 'event.dart';

class EventMessageRemoved implements Event {
  const EventMessageRemoved({
    required this.id,
    required this.properties,
  });

  factory EventMessageRemoved.fromJson(Map<String, dynamic> json) {
    return EventMessageRemoved(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.removed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

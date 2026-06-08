// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.023928Z

import 'event.dart';

class EventSessionNextToolInputStarted implements Event {
  const EventSessionNextToolInputStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolInputStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolInputStarted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.input.started",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:40:29.604853Z

import 'event.dart';

class EventSessionNextModelSwitched implements Event {
  const EventSessionNextModelSwitched({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextModelSwitched.fromJson(Map<String, dynamic> json) {
    return EventSessionNextModelSwitched(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.model.switched",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

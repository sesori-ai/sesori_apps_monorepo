// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.017637Z

import 'event.dart';

class EventSessionCompacted implements Event {
  const EventSessionCompacted({
    required this.id,
    required this.properties,
  });

  factory EventSessionCompacted.fromJson(Map<String, dynamic> json) {
    return EventSessionCompacted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.compacted",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.897085Z

import 'event.dart';

class EventSessionNextToolFailed implements Event {
  const EventSessionNextToolFailed({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolFailed.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolFailed(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.failed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

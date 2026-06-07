// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.652131Z

import 'event.dart';

class EventSessionNextToolCalled implements Event {
  const EventSessionNextToolCalled({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolCalled.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolCalled(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.called",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

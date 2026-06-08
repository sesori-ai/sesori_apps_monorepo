// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.889320Z

import 'event.dart';

class EventPermissionAsked implements Event {
  const EventPermissionAsked({
    required this.id,
    required this.properties,
  });

  factory EventPermissionAsked.fromJson(Map<String, dynamic> json) {
    return EventPermissionAsked(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.asked",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

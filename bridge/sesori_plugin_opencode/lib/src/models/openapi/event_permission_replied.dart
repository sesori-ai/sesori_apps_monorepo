// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.976577Z

import 'event.dart';

class EventPermissionReplied implements Event {
  const EventPermissionReplied({
    required this.id,
    required this.properties,
  });

  factory EventPermissionReplied.fromJson(Map<String, dynamic> json) {
    return EventPermissionReplied(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.replied",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

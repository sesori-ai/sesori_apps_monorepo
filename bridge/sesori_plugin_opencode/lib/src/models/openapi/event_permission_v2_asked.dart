// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.644826Z

import 'event.dart';

class EventPermissionV2Asked implements Event {
  const EventPermissionV2Asked({
    required this.id,
    required this.properties,
  });

  factory EventPermissionV2Asked.fromJson(Map<String, dynamic> json) {
    return EventPermissionV2Asked(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.v2.asked",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

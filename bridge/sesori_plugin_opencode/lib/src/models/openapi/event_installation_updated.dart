// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.642917Z

import 'event.dart';

class EventInstallationUpdated implements Event {
  const EventInstallationUpdated({
    required this.id,
    required this.properties,
  });

  factory EventInstallationUpdated.fromJson(Map<String, dynamic> json) {
    return EventInstallationUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "installation.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

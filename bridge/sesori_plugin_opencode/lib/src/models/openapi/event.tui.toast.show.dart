// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.641377Z

import 'event.dart';

class EventTuiToastShow190ap9t implements Event {
  const EventTuiToastShow190ap9t({
    required this.id,
    required this.properties,
  });

  factory EventTuiToastShow190ap9t.fromJson(Map<String, dynamic> json) {
    return EventTuiToastShow190ap9t(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "tui.toast.show",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

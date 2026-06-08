// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.323770Z

import 'event.dart';

class EventTuiPromptAppend1opz5ph implements Event {
  const EventTuiPromptAppend1opz5ph({
    required this.id,
    required this.properties,
  });

  factory EventTuiPromptAppend1opz5ph.fromJson(Map<String, dynamic> json) {
    return EventTuiPromptAppend1opz5ph(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "tui.prompt.append",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

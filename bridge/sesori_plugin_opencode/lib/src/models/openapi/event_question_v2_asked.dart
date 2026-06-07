// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.646653Z

import 'event.dart';

class EventQuestionV2Asked implements Event {
  const EventQuestionV2Asked({
    required this.id,
    required this.properties,
  });

  factory EventQuestionV2Asked.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2Asked(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.v2.asked",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

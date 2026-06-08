// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.891157Z

import 'event.dart';

class EventQuestionAsked implements Event {
  const EventQuestionAsked({
    required this.id,
    required this.properties,
  });

  factory EventQuestionAsked.fromJson(Map<String, dynamic> json) {
    return EventQuestionAsked(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.asked",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

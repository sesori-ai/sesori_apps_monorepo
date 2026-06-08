// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.959418Z

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventQuestionV2Replied implements Event {
  const EventQuestionV2Replied({
    required this.id,
    required this.properties,
  });

  factory EventQuestionV2Replied.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2Replied(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.v2.replied",
      "properties": properties,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventQuestionV2Replied &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final Map<String, dynamic> properties;
}

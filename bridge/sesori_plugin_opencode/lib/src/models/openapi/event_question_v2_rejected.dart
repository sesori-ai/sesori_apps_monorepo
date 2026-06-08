// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.925993Z

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventQuestionV2Rejected implements Event {
  const EventQuestionV2Rejected({
    required this.id,
    required this.properties,
  });

  factory EventQuestionV2Rejected.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2Rejected(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.v2.rejected",
      "properties": properties,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventQuestionV2Rejected &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final Map<String, dynamic> properties;
}

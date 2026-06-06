// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventQuestionRejected implements Event {
  const EventQuestionRejected({
    required this.id,
    required this.properties,
  });

  factory EventQuestionRejected.fromJson(Map<String, dynamic> json) {
    return EventQuestionRejected(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.rejected",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

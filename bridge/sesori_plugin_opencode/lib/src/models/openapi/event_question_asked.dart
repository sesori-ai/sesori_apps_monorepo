// GENERATED FILE - DO NOT EDIT BY HAND

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

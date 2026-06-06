// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventQuestionReplied implements Event {
  const EventQuestionReplied({
    required this.id,
    required this.properties,
  });

  factory EventQuestionReplied.fromJson(Map<String, dynamic> json) {
    return EventQuestionReplied(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "question.replied",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

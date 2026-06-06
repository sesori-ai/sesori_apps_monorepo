// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

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

  final String id;
  final Map<String, dynamic> properties;
}

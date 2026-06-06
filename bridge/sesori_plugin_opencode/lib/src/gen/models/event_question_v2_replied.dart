// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventQuestionV2Replied implements Event {
  const EventQuestionV2Replied({
    required this.id,
    required this.type,
    required this.properties,
  });

  factory EventQuestionV2Replied.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2Replied(
      id: json["id"] as String,
      type: json["type"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": type,
      "properties": properties,
    };
  }

  final String id;
  final String type;
  final Map<String, dynamic> properties;
}

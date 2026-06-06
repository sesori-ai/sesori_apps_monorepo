// GENERATED FILE - DO NOT EDIT BY HAND

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

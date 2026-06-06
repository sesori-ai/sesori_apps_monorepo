// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventQuestionV2Rejected implements Event {
  const EventQuestionV2Rejected({
    required this.id,
    required this.type,
    required this.properties,
  });

  factory EventQuestionV2Rejected.fromJson(Map<String, dynamic> json) {
    return EventQuestionV2Rejected(
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

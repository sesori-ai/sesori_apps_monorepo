// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextSynthetic implements Event {
  const EventSessionNextSynthetic({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextSynthetic.fromJson(Map<String, dynamic> json) {
    return EventSessionNextSynthetic(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.synthetic",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

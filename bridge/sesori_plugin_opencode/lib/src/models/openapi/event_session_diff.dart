// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionDiff implements Event {
  const EventSessionDiff({
    required this.id,
    required this.properties,
  });

  factory EventSessionDiff.fromJson(Map<String, dynamic> json) {
    return EventSessionDiff(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.diff",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

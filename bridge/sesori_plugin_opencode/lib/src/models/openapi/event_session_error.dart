// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionError implements Event {
  const EventSessionError({
    required this.id,
    required this.properties,
  });

  factory EventSessionError.fromJson(Map<String, dynamic> json) {
    return EventSessionError(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.error",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

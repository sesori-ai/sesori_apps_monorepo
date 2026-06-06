// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionStatus implements Event {
  const EventSessionStatus({
    required this.id,
    required this.properties,
  });

  factory EventSessionStatus.fromJson(Map<String, dynamic> json) {
    return EventSessionStatus(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.status",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

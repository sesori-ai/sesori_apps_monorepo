// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextPrompted implements Event {
  const EventSessionNextPrompted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextPrompted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextPrompted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.prompted",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

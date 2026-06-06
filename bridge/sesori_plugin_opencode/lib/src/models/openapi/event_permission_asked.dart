// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPermissionAsked implements Event {
  const EventPermissionAsked({
    required this.id,
    required this.properties,
  });

  factory EventPermissionAsked.fromJson(Map<String, dynamic> json) {
    return EventPermissionAsked(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.asked",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

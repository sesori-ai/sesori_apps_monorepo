// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPermissionReplied implements Event {
  const EventPermissionReplied({
    required this.id,
    required this.properties,
  });

  factory EventPermissionReplied.fromJson(Map<String, dynamic> json) {
    return EventPermissionReplied(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.replied",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

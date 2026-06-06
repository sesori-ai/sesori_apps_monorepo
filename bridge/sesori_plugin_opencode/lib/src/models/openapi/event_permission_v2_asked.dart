// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPermissionV2Asked implements Event {
  const EventPermissionV2Asked({
    required this.id,
    required this.type,
    required this.properties,
  });

  factory EventPermissionV2Asked.fromJson(Map<String, dynamic> json) {
    return EventPermissionV2Asked(
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

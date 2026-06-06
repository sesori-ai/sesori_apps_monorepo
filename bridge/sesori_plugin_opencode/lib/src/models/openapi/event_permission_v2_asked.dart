// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventPermissionV2Asked implements Event {
  const EventPermissionV2Asked({
    required this.id,
    required this.properties,
  });

  factory EventPermissionV2Asked.fromJson(Map<String, dynamic> json) {
    return EventPermissionV2Asked(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.v2.asked",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

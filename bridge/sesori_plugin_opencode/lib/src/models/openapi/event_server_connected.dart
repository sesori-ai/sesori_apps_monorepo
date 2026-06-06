// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventServerConnected implements Event {
  const EventServerConnected({
    required this.id,
    required this.properties,
  });

  factory EventServerConnected.fromJson(Map<String, dynamic> json) {
    return EventServerConnected(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "server.connected",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

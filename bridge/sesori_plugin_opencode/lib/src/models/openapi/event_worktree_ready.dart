// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventWorktreeReady implements Event {
  const EventWorktreeReady({
    required this.id,
    required this.type,
    required this.properties,
  });

  factory EventWorktreeReady.fromJson(Map<String, dynamic> json) {
    return EventWorktreeReady(
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

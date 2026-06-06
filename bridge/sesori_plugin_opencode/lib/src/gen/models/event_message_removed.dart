// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventMessageRemoved implements Event {
  const EventMessageRemoved({
    required this.id,
    required this.type,
    required this.properties,
  });

  factory EventMessageRemoved.fromJson(Map<String, dynamic> json) {
    return EventMessageRemoved(
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

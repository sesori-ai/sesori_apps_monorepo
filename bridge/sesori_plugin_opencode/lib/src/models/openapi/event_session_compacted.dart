// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionCompacted implements Event {
  const EventSessionCompacted({
    required this.id,
    required this.properties,
  });

  factory EventSessionCompacted.fromJson(Map<String, dynamic> json) {
    return EventSessionCompacted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.compacted",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

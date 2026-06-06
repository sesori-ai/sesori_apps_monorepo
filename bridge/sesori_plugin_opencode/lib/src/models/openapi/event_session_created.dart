// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionCreated implements Event {
  const EventSessionCreated({
    required this.id,
    required this.properties,
  });

  factory EventSessionCreated.fromJson(Map<String, dynamic> json) {
    return EventSessionCreated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.created",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

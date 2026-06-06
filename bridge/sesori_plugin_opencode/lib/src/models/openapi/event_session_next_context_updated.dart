// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextContextUpdated implements Event {
  const EventSessionNextContextUpdated({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextContextUpdated.fromJson(Map<String, dynamic> json) {
    return EventSessionNextContextUpdated(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.context.updated",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

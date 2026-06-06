// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextShellEnded implements Event {
  const EventSessionNextShellEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextShellEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextShellEnded(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.shell.ended",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextShellStarted implements Event {
  const EventSessionNextShellStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextShellStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextShellStarted(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.shell.started",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventSessionNextToolProgress implements Event {
  const EventSessionNextToolProgress({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolProgress.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolProgress(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.progress",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

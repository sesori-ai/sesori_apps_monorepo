// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventWorkspaceFailed implements Event {
  const EventWorkspaceFailed({
    required this.id,
    required this.properties,
  });

  factory EventWorkspaceFailed.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceFailed(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "workspace.failed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

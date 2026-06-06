// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventWorkspaceReady implements Event {
  const EventWorkspaceReady({
    required this.id,
    required this.properties,
  });

  factory EventWorkspaceReady.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceReady(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "workspace.ready",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

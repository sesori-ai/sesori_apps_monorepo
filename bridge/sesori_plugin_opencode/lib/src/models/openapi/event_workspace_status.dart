// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventWorkspaceStatus implements Event {
  const EventWorkspaceStatus({
    required this.id,
    required this.properties,
  });

  factory EventWorkspaceStatus.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceStatus(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "workspace.status",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

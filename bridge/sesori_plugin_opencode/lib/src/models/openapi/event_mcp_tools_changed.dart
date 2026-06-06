// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventMcpToolsChanged implements Event {
  const EventMcpToolsChanged({
    required this.id,
    required this.properties,
  });

  factory EventMcpToolsChanged.fromJson(Map<String, dynamic> json) {
    return EventMcpToolsChanged(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "mcp.tools.changed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

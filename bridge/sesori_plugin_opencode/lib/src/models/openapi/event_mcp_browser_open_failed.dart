// GENERATED FILE - DO NOT EDIT BY HAND

import 'event.dart';

class EventMcpBrowserOpenFailed implements Event {
  const EventMcpBrowserOpenFailed({
    required this.id,
    required this.properties,
  });

  factory EventMcpBrowserOpenFailed.fromJson(Map<String, dynamic> json) {
    return EventMcpBrowserOpenFailed(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "mcp.browser.open.failed",
      "properties": properties,
    };
  }

  final String id;
  final Map<String, dynamic> properties;
}

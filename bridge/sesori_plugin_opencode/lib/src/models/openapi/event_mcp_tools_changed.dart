// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventMcpToolsChanged implements Event {
  const EventMcpToolsChanged({
    required this.id,
    required this.properties,
  });

  factory EventMcpToolsChanged.fromJson(Map<String, dynamic> json) {
    return EventMcpToolsChanged(
      id: json["id"] as String,
      properties: EventMcpToolsChangedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "mcp.tools.changed",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMcpToolsChanged &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMcpToolsChangedProperties properties;
}

@immutable
class EventMcpToolsChangedProperties {
  const EventMcpToolsChangedProperties({
    required this.server,
  });

  factory EventMcpToolsChangedProperties.fromJson(Map<String, dynamic> json) {
    return EventMcpToolsChangedProperties(
      server: json["server"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "server": server,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMcpToolsChangedProperties &&
          other.server == server);

  @override
  int get hashCode => server.hashCode;

  final String server;
}

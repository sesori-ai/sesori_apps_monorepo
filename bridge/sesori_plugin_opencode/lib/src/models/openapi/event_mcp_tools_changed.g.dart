// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventMcpToolsChanged implements Event {
  const EventMcpToolsChanged({
    this.id = '',
    required this.properties,
  });

  factory EventMcpToolsChanged.fromJson(Map<String, dynamic> json) {
    return EventMcpToolsChanged(
      id: (json["id"] ?? '') as String,
      properties: EventMcpToolsChangedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMcpToolsChanged copyWith({
    String? id,
    EventMcpToolsChangedProperties? properties,
  }) {
    return EventMcpToolsChanged(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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
    this.server = '',
  });

  factory EventMcpToolsChangedProperties.fromJson(Map<String, dynamic> json) {
    return EventMcpToolsChangedProperties(
      server: (json["server"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "server": server,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMcpToolsChangedProperties copyWith({
    String? server,
  }) {
    return EventMcpToolsChangedProperties(
      server: server ?? this.server,
    );
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

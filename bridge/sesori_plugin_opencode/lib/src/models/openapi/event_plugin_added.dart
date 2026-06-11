// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventPluginAdded implements Event {
  const EventPluginAdded({
    required this.id,
    required this.properties,
  });

  factory EventPluginAdded.fromJson(Map<String, dynamic> json) {
    return EventPluginAdded(
      id: json["id"] as String,
      properties: EventPluginAddedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "plugin.added",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPluginAdded &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPluginAddedProperties properties;
}

@immutable
class EventPluginAddedProperties {
  const EventPluginAddedProperties({
    required this.id,
  });

  factory EventPluginAddedProperties.fromJson(Map<String, dynamic> json) {
    return EventPluginAddedProperties(
      id: json["id"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPluginAddedProperties &&
          other.id == id);

  @override
  int get hashCode => id.hashCode;

  final String id;
}

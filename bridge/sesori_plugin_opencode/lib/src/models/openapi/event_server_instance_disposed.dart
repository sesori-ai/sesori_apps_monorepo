// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventServerInstanceDisposed implements Event {
  const EventServerInstanceDisposed({
    required this.id,
    required this.properties,
  });

  factory EventServerInstanceDisposed.fromJson(Map<String, dynamic> json) {
    return EventServerInstanceDisposed(
      id: json["id"] as String,
      properties: EventServerInstanceDisposedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "server.instance.disposed",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventServerInstanceDisposed &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventServerInstanceDisposedProperties properties;
}

@immutable
class EventServerInstanceDisposedProperties {
  const EventServerInstanceDisposedProperties({
    required this.directory,
  });

  factory EventServerInstanceDisposedProperties.fromJson(Map<String, dynamic> json) {
    return EventServerInstanceDisposedProperties(
      directory: json["directory"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventServerInstanceDisposedProperties &&
          other.directory == directory);

  @override
  int get hashCode => directory.hashCode;

  final String directory;
}

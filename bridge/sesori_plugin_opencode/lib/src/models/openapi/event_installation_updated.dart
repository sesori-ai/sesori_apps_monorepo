// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventInstallationUpdated implements Event {
  const EventInstallationUpdated({
    required this.id,
    required this.properties,
  });

  factory EventInstallationUpdated.fromJson(Map<String, dynamic> json) {
    return EventInstallationUpdated(
      id: json["id"] as String,
      properties: EventInstallationUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "installation.updated",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventInstallationUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventInstallationUpdatedProperties properties;
}

@immutable
class EventInstallationUpdatedProperties {
  const EventInstallationUpdatedProperties({
    required this.version,
  });

  factory EventInstallationUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventInstallationUpdatedProperties(
      version: json["version"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "version": version,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventInstallationUpdatedProperties &&
          other.version == version);

  @override
  int get hashCode => version.hashCode;

  final String version;
}

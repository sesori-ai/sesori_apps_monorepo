// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventInstallationUpdateAvailable implements Event {
  const EventInstallationUpdateAvailable({
    required this.id,
    required this.properties,
  });

  factory EventInstallationUpdateAvailable.fromJson(Map<String, dynamic> json) {
    return EventInstallationUpdateAvailable(
      id: json["id"] as String,
      properties: EventInstallationUpdateAvailableProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "installation.update-available",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventInstallationUpdateAvailable &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventInstallationUpdateAvailableProperties properties;
}

@immutable
class EventInstallationUpdateAvailableProperties {
  const EventInstallationUpdateAvailableProperties({
    required this.version,
  });

  factory EventInstallationUpdateAvailableProperties.fromJson(Map<String, dynamic> json) {
    return EventInstallationUpdateAvailableProperties(
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
      (other is EventInstallationUpdateAvailableProperties &&
          other.version == version);

  @override
  int get hashCode => version.hashCode;

  final String version;
}

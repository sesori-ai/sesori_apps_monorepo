// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventInstallationUpdateAvailable copyWith({
    String? id,
    EventInstallationUpdateAvailableProperties? properties,
  }) {
    return EventInstallationUpdateAvailable(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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
      version: json["version"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "version": version,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventInstallationUpdateAvailableProperties copyWith({
    String? version,
  }) {
    return EventInstallationUpdateAvailableProperties(
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventInstallationUpdateAvailableProperties &&
          other.version == version);

  @override
  int get hashCode => version.hashCode;

  final String? version;
}

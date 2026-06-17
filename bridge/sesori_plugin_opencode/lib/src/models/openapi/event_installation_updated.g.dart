// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventInstallationUpdated copyWith({
    String? id,
    EventInstallationUpdatedProperties? properties,
  }) {
    return EventInstallationUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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
  EventInstallationUpdatedProperties copyWith({
    String? version,
  }) {
    return EventInstallationUpdatedProperties(
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventInstallationUpdatedProperties &&
          other.version == version);

  @override
  int get hashCode => version.hashCode;

  final String? version;
}

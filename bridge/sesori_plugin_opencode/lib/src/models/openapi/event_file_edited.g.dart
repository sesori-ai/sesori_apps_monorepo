// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventFileEdited implements Event {
  const EventFileEdited({
    this.id = '',
    required this.properties,
  });

  factory EventFileEdited.fromJson(Map<String, dynamic> json) {
    return EventFileEdited(
      id: (json["id"] ?? '') as String,
      properties: EventFileEditedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "file.edited",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventFileEdited copyWith({
    String? id,
    EventFileEditedProperties? properties,
  }) {
    return EventFileEdited(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventFileEdited &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventFileEditedProperties properties;
}

@immutable
class EventFileEditedProperties {
  const EventFileEditedProperties({
    this.file = '',
  });

  factory EventFileEditedProperties.fromJson(Map<String, dynamic> json) {
    return EventFileEditedProperties(
      file: (json["file"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": file,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventFileEditedProperties copyWith({
    String? file,
  }) {
    return EventFileEditedProperties(
      file: file ?? this.file,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventFileEditedProperties &&
          other.file == file);

  @override
  int get hashCode => file.hashCode;

  final String file;
}

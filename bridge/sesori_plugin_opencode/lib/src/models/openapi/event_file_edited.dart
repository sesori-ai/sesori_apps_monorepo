// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventFileEdited implements Event {
  const EventFileEdited({
    required this.id,
    required this.properties,
  });

  factory EventFileEdited.fromJson(Map<String, dynamic> json) {
    return EventFileEdited(
      id: json["id"] as String,
      properties: EventFileEditedProperties.fromJson(json["properties"] as Map<String, dynamic>),
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
    required this.file,
  });

  factory EventFileEditedProperties.fromJson(Map<String, dynamic> json) {
    return EventFileEditedProperties(
      file: json["file"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": file,
    };
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

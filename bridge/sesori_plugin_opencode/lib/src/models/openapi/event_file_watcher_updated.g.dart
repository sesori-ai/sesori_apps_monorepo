// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventFileWatcherUpdated implements Event {
  const EventFileWatcherUpdated({
    required this.id,
    required this.properties,
  });

  factory EventFileWatcherUpdated.fromJson(Map<String, dynamic> json) {
    return EventFileWatcherUpdated(
      id: json["id"] as String,
      properties: EventFileWatcherUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "file.watcher.updated",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventFileWatcherUpdated copyWith({
    String? id,
    EventFileWatcherUpdatedProperties? properties,
  }) {
    return EventFileWatcherUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventFileWatcherUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventFileWatcherUpdatedProperties properties;
}

@immutable
class EventFileWatcherUpdatedProperties {
  const EventFileWatcherUpdatedProperties({
    required this.file,
    required this.event,
  });

  factory EventFileWatcherUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventFileWatcherUpdatedProperties(
      file: json["file"] as String,
      event: EventFileWatcherUpdatedPropertiesEvent.fromJson(json["event"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": file,
      "event": event.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventFileWatcherUpdatedProperties copyWith({
    String? file,
    EventFileWatcherUpdatedPropertiesEvent? event,
  }) {
    return EventFileWatcherUpdatedProperties(
      file: file ?? this.file,
      event: event ?? this.event,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventFileWatcherUpdatedProperties &&
          other.file == file &&
          other.event == event);

  @override
  int get hashCode => Object.hash(file, event);

  final String file;
  final EventFileWatcherUpdatedPropertiesEvent event;
}

enum EventFileWatcherUpdatedPropertiesEvent {
  @JsonValue("add")
  add,
  @JsonValue("change")
  change,
  @JsonValue("unlink")
  unlink,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static EventFileWatcherUpdatedPropertiesEvent fromJson(String value) {
    switch (value) {
      case "add":
        return EventFileWatcherUpdatedPropertiesEvent.add;
      case "change":
        return EventFileWatcherUpdatedPropertiesEvent.change;
      case "unlink":
        return EventFileWatcherUpdatedPropertiesEvent.unlink;
      default:
        return EventFileWatcherUpdatedPropertiesEvent.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case EventFileWatcherUpdatedPropertiesEvent.add:
        return "add";
      case EventFileWatcherUpdatedPropertiesEvent.change:
        return "change";
      case EventFileWatcherUpdatedPropertiesEvent.unlink:
        return "unlink";
      case EventFileWatcherUpdatedPropertiesEvent.unknown:
        return 'unknown';
    }
  }
}

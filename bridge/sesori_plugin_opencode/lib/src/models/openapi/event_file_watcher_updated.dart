// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

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
      event: json["event"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "file": file,
      "event": event,
    };
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
  final String event;
}

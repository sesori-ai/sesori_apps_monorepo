// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.210672Z

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
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "file.watcher.updated",
      "properties": properties,
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
  final Map<String, dynamic> properties;
}

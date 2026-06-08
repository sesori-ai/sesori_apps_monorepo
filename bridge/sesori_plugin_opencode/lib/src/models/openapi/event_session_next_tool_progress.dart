// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.965581Z

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextToolProgress implements Event {
  const EventSessionNextToolProgress({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolProgress.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolProgress(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.progress",
      "properties": properties,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolProgress &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final Map<String, dynamic> properties;
}

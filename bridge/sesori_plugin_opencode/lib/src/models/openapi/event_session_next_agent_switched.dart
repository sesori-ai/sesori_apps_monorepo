// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.217894Z

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextAgentSwitched implements Event {
  const EventSessionNextAgentSwitched({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextAgentSwitched.fromJson(Map<String, dynamic> json) {
    return EventSessionNextAgentSwitched(
      id: json["id"] as String,
      properties: json["properties"] as Map<String, dynamic>,
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.agent.switched",
      "properties": properties,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextAgentSwitched &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final Map<String, dynamic> properties;
}

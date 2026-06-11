// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

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
      properties: EventSessionNextAgentSwitchedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.agent.switched",
      "properties": properties.toJson(),
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
  final EventSessionNextAgentSwitchedProperties properties;
}

@immutable
class EventSessionNextAgentSwitchedProperties {
  const EventSessionNextAgentSwitchedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.agent,
  });

  factory EventSessionNextAgentSwitchedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextAgentSwitchedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      agent: json["agent"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "agent": agent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextAgentSwitchedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.agent == agent);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, agent);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final String agent;
}

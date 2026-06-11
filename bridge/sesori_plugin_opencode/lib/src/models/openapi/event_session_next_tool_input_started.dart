// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextToolInputStarted implements Event {
  const EventSessionNextToolInputStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolInputStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolInputStarted(
      id: json["id"] as String,
      properties: EventSessionNextToolInputStartedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.input.started",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolInputStarted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextToolInputStartedProperties properties;
}

@immutable
class EventSessionNextToolInputStartedProperties {
  const EventSessionNextToolInputStartedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.name,
  });

  factory EventSessionNextToolInputStartedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolInputStartedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      name: json["name"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "name": name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolInputStartedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.name == name);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, name);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final String name;
}

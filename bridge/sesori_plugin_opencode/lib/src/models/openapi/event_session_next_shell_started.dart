// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextShellStarted implements Event {
  const EventSessionNextShellStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextShellStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextShellStarted(
      id: json["id"] as String,
      properties: EventSessionNextShellStartedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.shell.started",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextShellStarted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextShellStartedProperties properties;
}

@immutable
class EventSessionNextShellStartedProperties {
  const EventSessionNextShellStartedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.callID,
    required this.command,
  });

  factory EventSessionNextShellStartedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextShellStartedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      callID: json["callID"] as String,
      command: json["command"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "callID": callID,
      "command": command,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextShellStartedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.callID == callID &&
          other.command == command);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, callID, command);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final String callID;
  final String command;
}

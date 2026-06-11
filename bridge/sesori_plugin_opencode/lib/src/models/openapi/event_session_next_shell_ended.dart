// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextShellEnded implements Event {
  const EventSessionNextShellEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextShellEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextShellEnded(
      id: json["id"] as String,
      properties: EventSessionNextShellEndedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.shell.ended",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextShellEnded &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextShellEndedProperties properties;
}

@immutable
class EventSessionNextShellEndedProperties {
  const EventSessionNextShellEndedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.callID,
    required this.output,
  });

  factory EventSessionNextShellEndedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextShellEndedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      callID: json["callID"] as String,
      output: json["output"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "callID": callID,
      "output": output,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextShellEndedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.callID == callID &&
          other.output == output);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, callID, output);

  final double timestamp;
  final String sessionID;
  final String callID;
  final String output;
}

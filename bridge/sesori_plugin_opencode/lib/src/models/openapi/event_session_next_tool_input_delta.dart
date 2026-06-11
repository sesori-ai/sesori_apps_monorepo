// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextToolInputDelta implements Event {
  const EventSessionNextToolInputDelta({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolInputDelta.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolInputDelta(
      id: json["id"] as String,
      properties: EventSessionNextToolInputDeltaProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.input.delta",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolInputDelta &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextToolInputDeltaProperties properties;
}

@immutable
class EventSessionNextToolInputDeltaProperties {
  const EventSessionNextToolInputDeltaProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.delta,
  });

  factory EventSessionNextToolInputDeltaProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolInputDeltaProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      delta: json["delta"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "delta": delta,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolInputDeltaProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.delta == delta);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, delta);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final String delta;
}

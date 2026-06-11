// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextReasoningDelta implements Event {
  const EventSessionNextReasoningDelta({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextReasoningDelta.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningDelta(
      id: json["id"] as String,
      properties: EventSessionNextReasoningDeltaProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.reasoning.delta",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextReasoningDelta &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextReasoningDeltaProperties properties;
}

@immutable
class EventSessionNextReasoningDeltaProperties {
  const EventSessionNextReasoningDeltaProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.reasoningID,
    required this.delta,
  });

  factory EventSessionNextReasoningDeltaProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningDeltaProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      reasoningID: json["reasoningID"] as String,
      delta: json["delta"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "reasoningID": reasoningID,
      "delta": delta,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextReasoningDeltaProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.reasoningID == reasoningID &&
          other.delta == delta);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, reasoningID, delta);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String reasoningID;
  final String delta;
}

// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextReasoningStarted implements Event {
  const EventSessionNextReasoningStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextReasoningStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningStarted(
      id: json["id"] as String,
      properties: EventSessionNextReasoningStartedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.reasoning.started",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextReasoningStarted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextReasoningStartedProperties properties;
}

@immutable
class EventSessionNextReasoningStartedProperties {
  const EventSessionNextReasoningStartedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.reasoningID,
    this.providerMetadata,
  });

  factory EventSessionNextReasoningStartedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningStartedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      reasoningID: json["reasoningID"] as String,
      providerMetadata: (json["providerMetadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "reasoningID": reasoningID,
      "providerMetadata": ?providerMetadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextReasoningStartedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.reasoningID == reasoningID &&
          const DeepCollectionEquality().equals(other.providerMetadata, providerMetadata));

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, reasoningID, const DeepCollectionEquality().hash(providerMetadata));

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String reasoningID;
  final Map<String, Map<String, dynamic>>? providerMetadata;
}

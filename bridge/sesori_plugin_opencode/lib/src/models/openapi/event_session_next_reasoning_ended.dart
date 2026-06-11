// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextReasoningEnded implements Event {
  const EventSessionNextReasoningEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextReasoningEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningEnded(
      id: json["id"] as String,
      properties: EventSessionNextReasoningEndedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.reasoning.ended",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextReasoningEnded &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextReasoningEndedProperties properties;
}

@immutable
class EventSessionNextReasoningEndedProperties {
  const EventSessionNextReasoningEndedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.reasoningID,
    required this.text,
    this.providerMetadata,
  });

  factory EventSessionNextReasoningEndedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextReasoningEndedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      reasoningID: json["reasoningID"] as String,
      text: json["text"] as String,
      providerMetadata: (json["providerMetadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "reasoningID": reasoningID,
      "text": text,
      "providerMetadata": ?providerMetadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextReasoningEndedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.reasoningID == reasoningID &&
          other.text == text &&
          const DeepCollectionEquality().equals(other.providerMetadata, providerMetadata));

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, reasoningID, text, const DeepCollectionEquality().hash(providerMetadata));

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String reasoningID;
  final String text;
  final Map<String, Map<String, dynamic>>? providerMetadata;
}

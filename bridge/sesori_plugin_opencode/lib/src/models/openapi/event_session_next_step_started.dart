// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextStepStarted implements Event {
  const EventSessionNextStepStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextStepStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepStarted(
      id: json["id"] as String,
      properties: EventSessionNextStepStartedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.step.started",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextStepStarted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextStepStartedProperties properties;
}

@immutable
class EventSessionNextStepStartedProperties {
  const EventSessionNextStepStartedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.agent,
    required this.model,
    this.snapshot,
  });

  factory EventSessionNextStepStartedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepStartedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      agent: json["agent"] as String,
      model: EventSessionNextStepStartedPropertiesModel.fromJson(json["model"] as Map<String, dynamic>),
      snapshot: json["snapshot"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "agent": agent,
      "model": model.toJson(),
      "snapshot": ?snapshot,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextStepStartedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.agent == agent &&
          other.model == model &&
          other.snapshot == snapshot);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, agent, model, snapshot);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String agent;
  final EventSessionNextStepStartedPropertiesModel model;
  final String? snapshot;
}

@immutable
class EventSessionNextStepStartedPropertiesModel {
  const EventSessionNextStepStartedPropertiesModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory EventSessionNextStepStartedPropertiesModel.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepStartedPropertiesModel(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextStepStartedPropertiesModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}

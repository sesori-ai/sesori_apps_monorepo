// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextModelSwitched implements Event {
  const EventSessionNextModelSwitched({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextModelSwitched.fromJson(Map<String, dynamic> json) {
    return EventSessionNextModelSwitched(
      id: json["id"] as String,
      properties: EventSessionNextModelSwitchedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.model.switched",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextModelSwitched &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextModelSwitchedProperties properties;
}

@immutable
class EventSessionNextModelSwitchedProperties {
  const EventSessionNextModelSwitchedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.model,
  });

  factory EventSessionNextModelSwitchedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextModelSwitchedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      model: EventSessionNextModelSwitchedPropertiesModel.fromJson(json["model"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "model": model.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextModelSwitchedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.model == model);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, model);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final EventSessionNextModelSwitchedPropertiesModel model;
}

@immutable
class EventSessionNextModelSwitchedPropertiesModel {
  const EventSessionNextModelSwitchedPropertiesModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory EventSessionNextModelSwitchedPropertiesModel.fromJson(Map<String, dynamic> json) {
    return EventSessionNextModelSwitchedPropertiesModel(
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
      (other is EventSessionNextModelSwitchedPropertiesModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}

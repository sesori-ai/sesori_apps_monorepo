// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventMessagePartDelta implements Event {
  const EventMessagePartDelta({
    required this.id,
    required this.properties,
  });

  factory EventMessagePartDelta.fromJson(Map<String, dynamic> json) {
    return EventMessagePartDelta(
      id: json["id"] as String,
      properties: EventMessagePartDeltaProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.part.delta",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessagePartDelta &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMessagePartDeltaProperties properties;
}

@immutable
class EventMessagePartDeltaProperties {
  const EventMessagePartDeltaProperties({
    required this.sessionID,
    required this.messageID,
    required this.partID,
    required this.field,
    required this.delta,
  });

  factory EventMessagePartDeltaProperties.fromJson(Map<String, dynamic> json) {
    return EventMessagePartDeltaProperties(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      partID: json["partID"] as String,
      field: json["field"] as String,
      delta: json["delta"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "messageID": messageID,
      "partID": partID,
      "field": field,
      "delta": delta,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessagePartDeltaProperties &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.partID == partID &&
          other.field == field &&
          other.delta == delta);

  @override
  int get hashCode => Object.hash(sessionID, messageID, partID, field, delta);

  final String sessionID;
  final String messageID;
  final String partID;
  final String field;
  final String delta;
}

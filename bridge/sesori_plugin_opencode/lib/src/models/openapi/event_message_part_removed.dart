// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventMessagePartRemoved implements Event {
  const EventMessagePartRemoved({
    required this.id,
    required this.properties,
  });

  factory EventMessagePartRemoved.fromJson(Map<String, dynamic> json) {
    return EventMessagePartRemoved(
      id: json["id"] as String,
      properties: EventMessagePartRemovedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.part.removed",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessagePartRemoved &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMessagePartRemovedProperties properties;
}

@immutable
class EventMessagePartRemovedProperties {
  const EventMessagePartRemovedProperties({
    required this.sessionID,
    required this.messageID,
    required this.partID,
  });

  factory EventMessagePartRemovedProperties.fromJson(Map<String, dynamic> json) {
    return EventMessagePartRemovedProperties(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      partID: json["partID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "messageID": messageID,
      "partID": partID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessagePartRemovedProperties &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.partID == partID);

  @override
  int get hashCode => Object.hash(sessionID, messageID, partID);

  final String sessionID;
  final String messageID;
  final String partID;
}

// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventMessageRemoved implements Event {
  const EventMessageRemoved({
    required this.id,
    required this.properties,
  });

  factory EventMessageRemoved.fromJson(Map<String, dynamic> json) {
    return EventMessageRemoved(
      id: json["id"] as String,
      properties: EventMessageRemovedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.removed",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessageRemoved &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMessageRemovedProperties properties;
}

@immutable
class EventMessageRemovedProperties {
  const EventMessageRemovedProperties({
    required this.sessionID,
    required this.messageID,
  });

  factory EventMessageRemovedProperties.fromJson(Map<String, dynamic> json) {
    return EventMessageRemovedProperties(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "messageID": messageID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessageRemovedProperties &&
          other.sessionID == sessionID &&
          other.messageID == messageID);

  @override
  int get hashCode => Object.hash(sessionID, messageID);

  final String sessionID;
  final String messageID;
}

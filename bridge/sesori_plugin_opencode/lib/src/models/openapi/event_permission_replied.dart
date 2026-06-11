// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventPermissionReplied implements Event {
  const EventPermissionReplied({
    required this.id,
    required this.properties,
  });

  factory EventPermissionReplied.fromJson(Map<String, dynamic> json) {
    return EventPermissionReplied(
      id: json["id"] as String,
      properties: EventPermissionRepliedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.replied",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPermissionReplied &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPermissionRepliedProperties properties;
}

@immutable
class EventPermissionRepliedProperties {
  const EventPermissionRepliedProperties({
    required this.sessionID,
    required this.requestID,
    required this.reply,
  });

  factory EventPermissionRepliedProperties.fromJson(Map<String, dynamic> json) {
    return EventPermissionRepliedProperties(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
      reply: json["reply"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
      "reply": reply,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPermissionRepliedProperties &&
          other.sessionID == sessionID &&
          other.requestID == requestID &&
          other.reply == reply);

  @override
  int get hashCode => Object.hash(sessionID, requestID, reply);

  final String sessionID;
  final String requestID;
  final String reply;
}

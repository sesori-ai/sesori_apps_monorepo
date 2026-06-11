// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'permission_v2_reply.dart';

@immutable
class EventPermissionV2Replied implements Event {
  const EventPermissionV2Replied({
    required this.id,
    required this.properties,
  });

  factory EventPermissionV2Replied.fromJson(Map<String, dynamic> json) {
    return EventPermissionV2Replied(
      id: json["id"] as String,
      properties: EventPermissionV2RepliedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.v2.replied",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPermissionV2Replied &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPermissionV2RepliedProperties properties;
}

@immutable
class EventPermissionV2RepliedProperties {
  const EventPermissionV2RepliedProperties({
    required this.sessionID,
    required this.requestID,
    required this.reply,
  });

  factory EventPermissionV2RepliedProperties.fromJson(Map<String, dynamic> json) {
    return EventPermissionV2RepliedProperties(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
      reply: PermissionV2Reply.fromJson(json["reply"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
      "reply": reply.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPermissionV2RepliedProperties &&
          other.sessionID == sessionID &&
          other.requestID == requestID &&
          other.reply == reply);

  @override
  int get hashCode => Object.hash(sessionID, requestID, reply);

  final String sessionID;
  final String requestID;
  final PermissionV2Reply reply;
}

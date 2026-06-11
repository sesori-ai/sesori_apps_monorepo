// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventPermissionReplied implements Event {
  const EventPermissionReplied({
    this.id = '',
    required this.properties,
  });

  factory EventPermissionReplied.fromJson(Map<String, dynamic> json) {
    return EventPermissionReplied(
      id: (json["id"] ?? '') as String,
      properties: EventPermissionRepliedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPermissionReplied copyWith({
    String? id,
    EventPermissionRepliedProperties? properties,
  }) {
    return EventPermissionReplied(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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
    this.sessionID = '',
    this.requestID = '',
    this.reply = '',
  });

  factory EventPermissionRepliedProperties.fromJson(Map<String, dynamic> json) {
    return EventPermissionRepliedProperties(
      sessionID: (json["sessionID"] ?? '') as String,
      requestID: (json["requestID"] ?? '') as String,
      reply: (json["reply"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
      "reply": reply,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPermissionRepliedProperties copyWith({
    String? sessionID,
    String? requestID,
    String? reply,
  }) {
    return EventPermissionRepliedProperties(
      sessionID: sessionID ?? this.sessionID,
      requestID: requestID ?? this.requestID,
      reply: reply ?? this.reply,
    );
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

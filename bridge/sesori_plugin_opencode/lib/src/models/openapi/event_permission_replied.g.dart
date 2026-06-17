// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

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
    required this.sessionID,
    required this.requestID,
    required this.reply,
  });

  factory EventPermissionRepliedProperties.fromJson(Map<String, dynamic> json) {
    return EventPermissionRepliedProperties(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
      reply: EventPermissionRepliedPropertiesReply.fromJson(json["reply"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
      "reply": reply.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPermissionRepliedProperties copyWith({
    String? sessionID,
    String? requestID,
    EventPermissionRepliedPropertiesReply? reply,
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
  final EventPermissionRepliedPropertiesReply reply;
}

enum EventPermissionRepliedPropertiesReply {
  @JsonValue("once")
  once,
  @JsonValue("always")
  always,
  @JsonValue("reject")
  reject,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static EventPermissionRepliedPropertiesReply fromJson(String value) {
    switch (value) {
      case "once":
        return EventPermissionRepliedPropertiesReply.once;
      case "always":
        return EventPermissionRepliedPropertiesReply.always;
      case "reject":
        return EventPermissionRepliedPropertiesReply.reject;
      default:
        return EventPermissionRepliedPropertiesReply.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case EventPermissionRepliedPropertiesReply.once:
        return "once";
      case EventPermissionRepliedPropertiesReply.always:
        return "always";
      case EventPermissionRepliedPropertiesReply.reject:
        return "reject";
      case EventPermissionRepliedPropertiesReply.unknown:
        return 'unknown';
    }
  }
}

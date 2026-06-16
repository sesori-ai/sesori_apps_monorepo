// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventPermissionAsked implements Event {
  const EventPermissionAsked({
    required this.id,
    required this.properties,
  });

  factory EventPermissionAsked.fromJson(Map<String, dynamic> json) {
    return EventPermissionAsked(
      id: json["id"] as String,
      properties: EventPermissionAskedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "permission.asked",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPermissionAsked copyWith({
    String? id,
    EventPermissionAskedProperties? properties,
  }) {
    return EventPermissionAsked(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPermissionAsked &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPermissionAskedProperties properties;
}

@immutable
class EventPermissionAskedProperties {
  const EventPermissionAskedProperties({
    required this.id,
    required this.sessionID,
    required this.permission,
    required this.patterns,
    required this.metadata,
    required this.always,
    required this.tool,
  });

  factory EventPermissionAskedProperties.fromJson(Map<String, dynamic> json) {
    return EventPermissionAskedProperties(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      permission: json["permission"] as String,
      patterns: (json["patterns"] as List<dynamic>).cast<String>(),
      metadata: json["metadata"] as Map<String, dynamic>,
      always: (json["always"] as List<dynamic>).cast<String>(),
      tool: json["tool"] == null ? null : EventPermissionAskedPropertiesTool.fromJson(json["tool"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "permission": permission,
      "patterns": patterns,
      "metadata": metadata,
      "always": always,
      "tool": ?tool?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPermissionAskedProperties copyWith({
    String? id,
    String? sessionID,
    String? permission,
    List<String>? patterns,
    Map<String, dynamic>? metadata,
    List<String>? always,
    EventPermissionAskedPropertiesTool? tool,
  }) {
    return EventPermissionAskedProperties(
      id: id ?? this.id,
      sessionID: sessionID ?? this.sessionID,
      permission: permission ?? this.permission,
      patterns: patterns ?? this.patterns,
      metadata: metadata ?? this.metadata,
      always: always ?? this.always,
      tool: tool ?? this.tool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPermissionAskedProperties &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.permission == permission &&
          const DeepCollectionEquality().equals(other.patterns, patterns) &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          const DeepCollectionEquality().equals(other.always, always) &&
          other.tool == tool);

  @override
  int get hashCode => Object.hash(id, sessionID, permission, const DeepCollectionEquality().hash(patterns), const DeepCollectionEquality().hash(metadata), const DeepCollectionEquality().hash(always), tool);

  final String id;
  final String sessionID;
  final String permission;
  final List<String> patterns;
  final Map<String, dynamic> metadata;
  final List<String> always;
  final EventPermissionAskedPropertiesTool? tool;
}

@immutable
class EventPermissionAskedPropertiesTool {
  const EventPermissionAskedPropertiesTool({
    required this.messageID,
    required this.callID,
  });

  factory EventPermissionAskedPropertiesTool.fromJson(Map<String, dynamic> json) {
    return EventPermissionAskedPropertiesTool(
      messageID: json["messageID"] as String,
      callID: json["callID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "messageID": messageID,
      "callID": callID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPermissionAskedPropertiesTool copyWith({
    String? messageID,
    String? callID,
  }) {
    return EventPermissionAskedPropertiesTool(
      messageID: messageID ?? this.messageID,
      callID: callID ?? this.callID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPermissionAskedPropertiesTool &&
          other.messageID == messageID &&
          other.callID == callID);

  @override
  int get hashCode => Object.hash(messageID, callID);

  final String messageID;
  final String callID;
}

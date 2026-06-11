// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventCommandExecuted implements Event {
  const EventCommandExecuted({
    this.id = '',
    required this.properties,
  });

  factory EventCommandExecuted.fromJson(Map<String, dynamic> json) {
    return EventCommandExecuted(
      id: (json["id"] ?? '') as String,
      properties: EventCommandExecutedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "command.executed",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventCommandExecuted copyWith({
    String? id,
    EventCommandExecutedProperties? properties,
  }) {
    return EventCommandExecuted(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventCommandExecuted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventCommandExecutedProperties properties;
}

@immutable
class EventCommandExecutedProperties {
  const EventCommandExecutedProperties({
    this.name = '',
    this.sessionID = '',
    this.arguments = '',
    this.messageID = '',
  });

  factory EventCommandExecutedProperties.fromJson(Map<String, dynamic> json) {
    return EventCommandExecutedProperties(
      name: (json["name"] ?? '') as String,
      sessionID: (json["sessionID"] ?? '') as String,
      arguments: (json["arguments"] ?? '') as String,
      messageID: (json["messageID"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "sessionID": sessionID,
      "arguments": arguments,
      "messageID": messageID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventCommandExecutedProperties copyWith({
    String? name,
    String? sessionID,
    String? arguments,
    String? messageID,
  }) {
    return EventCommandExecutedProperties(
      name: name ?? this.name,
      sessionID: sessionID ?? this.sessionID,
      arguments: arguments ?? this.arguments,
      messageID: messageID ?? this.messageID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventCommandExecutedProperties &&
          other.name == name &&
          other.sessionID == sessionID &&
          other.arguments == arguments &&
          other.messageID == messageID);

  @override
  int get hashCode => Object.hash(name, sessionID, arguments, messageID);

  final String name;
  final String sessionID;
  final String arguments;
  final String messageID;
}

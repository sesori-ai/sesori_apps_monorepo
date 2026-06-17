// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessagePartRemoved copyWith({
    String? id,
    EventMessagePartRemovedProperties? properties,
  }) {
    return EventMessagePartRemoved(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessagePartRemovedProperties copyWith({
    String? sessionID,
    String? messageID,
    String? partID,
  }) {
    return EventMessagePartRemovedProperties(
      sessionID: sessionID ?? this.sessionID,
      messageID: messageID ?? this.messageID,
      partID: partID ?? this.partID,
    );
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
